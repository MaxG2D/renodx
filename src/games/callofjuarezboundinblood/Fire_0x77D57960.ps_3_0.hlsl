#include "./shared.h"
#include "./FakeHDRGain.hlsl"

float4 CONST_110 : register(c0); 
float4 RENDER_TARGET_PARAMS_BIAS : register(c1);
sampler2D s_t00 : register(s0); 
sampler2D s_t02 : register(s2); 

struct PS_IN
{
    float2 texcoord : TEXCOORD0;
    float texcoord5 : TEXCOORD5; 
    float3 texcoord7 : TEXCOORD7; 
    float2 vPos : VPOS;
};

float4 main(PS_IN i) : COLOR
{
    // 1. Screen UV & Depth Fade
    float2 screenUV = i.vPos.xy * RENDER_TARGET_PARAMS_BIAS.xy + RENDER_TARGET_PARAMS_BIAS.zw;
    float sceneDepth = tex2D(s_t02, screenUV).x;
    float fade = saturate((sceneDepth - i.texcoord5) * CONST_110.z);

    // 2. Texture Sampling & Squaring (The "De-wash" step)
    float4 fireTex = tex2D(s_t00, i.texcoord);
    
    // Squaring the color makes the gradients sharper and the "hot" spots more defined
    float3 squaredColor = fireTex.rgb * fireTex.rgb;

    // 3. Applying Tint and Fade
    // We use the Vertex Tint (texcoord7) and the Depth Fade
    float3 finalRGB = squaredColor * i.texcoord7.rgb * 5 * fade;

    // 4. Alpha Fix
    // If it's still too bright, we might need to multiply alpha by the fade
    // to ensure the edges of the particle aren't "boxy."
    float finalAlpha = fireTex.a * fade;

    return float4(finalRGB, finalAlpha);
}