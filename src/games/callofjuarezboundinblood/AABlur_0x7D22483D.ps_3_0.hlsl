#include "./shared.h"

float4 CONST_101 : register(c0); // .w = Min Edge Weight
float4 CONST_103 : register(c1); // .xy = Depth Fade Params, .zw = Noise Params

sampler2D s_depth : register(s0);
sampler2D s_noise : register(s1);

struct PS_IN
{
    float4 texcoord  : TEXCOORD0; // .xy = Center UV, .zw = Noise UV
    float3 texcoord1 : TEXCOORD1; // Packed UVs for Depth Offsets
    float3 texcoord2 : TEXCOORD2;
    float3 texcoord3 : TEXCOORD3;
    float3 texcoord4 : TEXCOORD4;
};

float4 main(PS_IN i) : COLOR
{
    float4 o;

    // --- Heatwave / Noise Effect ---
    // Sample noise, scale, and fade by depth
    float2 noise = tex2D(s_noise, i.texcoord.zw).xy;
    noise = noise * CONST_103.z + CONST_103.w;

    float centerDepth = tex2Dlod(s_depth, float4(i.texcoord.xy, 0, 0)).x;

    // Depth Fade
    float fade = saturate(centerDepth * CONST_103.x + CONST_103.y);
    fade = fade * fade;
    fade = fade * fade;

    float2 heatwaveOffset = noise * fade;
    o.xy = heatwaveOffset * 0.5 + 0.5;

    // Edge Detection (Anti-Aliasing) ---
    // Unpack 8 surrounding UVs and sample depth
    float d1 = tex2Dlod(s_depth, float4(i.texcoord1.x, i.texcoord1.z, 0, 0)).x;
    float d2 = tex2Dlod(s_depth, float4(i.texcoord1.y, i.texcoord1.z, 0, 0)).x;
    float d3 = tex2Dlod(s_depth, float4(i.texcoord2.x, i.texcoord2.z, 0, 0)).x;
    float d4 = tex2Dlod(s_depth, float4(i.texcoord2.y, i.texcoord2.z, 0, 0)).x;
    
    float d5 = tex2Dlod(s_depth, float4(i.texcoord3.x, i.texcoord3.y, 0, 0)).x;
    float d6 = tex2Dlod(s_depth, float4(i.texcoord3.x, i.texcoord3.z, 0, 0)).x;
    float d7 = tex2Dlod(s_depth, float4(i.texcoord4.x, i.texcoord4.y, 0, 0)).x;
    float d8 = tex2Dlod(s_depth, float4(i.texcoord4.x, i.texcoord4.z, 0, 0)).x;

    // Group into opposite pairs, average them, and subtract center
    float4 depthPairs = float4(d1 + d3, d2 + d4, d5 + d7, d6 + d8);
    float4 diff = depthPairs * 0.5 - centerDepth;

    // Calculate relative depth difference threshold (0.01 threshold)
    float invDepth = 1.0 / centerDepth;
    float4 edgeThreshold = abs(diff) * invDepth - 0.01;

    // Hardware cmp instruction -> Is it an edge?
    float4 isEdge = (edgeThreshold >= 0.0) ? 1.0 : 0.0;

    // Cross-multiply opposite axes
    float2 combinedEdges = isEdge.zw * isEdge.xy;

    // dp2add - Combine axes with a weight. 0.3 is vanilla.
    float finalEdge = dot(combinedEdges, float2(0.3 * CUSTOM_AA_BLUR_STRENGTH, 0.3 * CUSTOM_AA_BLUR_STRENGTH));

    // ZW Output
    o.z = max(CONST_101.w, finalEdge);
    o.w = 0.5;

    return o;
}