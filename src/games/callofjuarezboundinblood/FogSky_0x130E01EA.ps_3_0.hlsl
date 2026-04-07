#include "./shared.h"

// --- Registers ---
float4 INV_FRUSTUM[2]     : register(c0); // c0 and c1
float4 INVVIEW_XFORM[2]   : register(c2); // c2 and c3
float4 CONST_102       : register(c4); // .x = Fog Bias, .y = Fog Scale
float4 CONST_103       : register(c5); // .y = Height Threshold, .z = Min Density
float4 CONST_104       : register(c6); // .xy = Height Scales, .zw = Height Biases
float4 CONST_105       : register(c7); // .xyz = Alt Sky, .w = Fog Density Multiplier
float3 vSunDir         : register(c8); 
float4 RT_PARAMS_BIAS  : register(c9); 
float4 CONST_70        : register(c10); // Global Sky Scale
float4 CONST_73        : register(c11); // Atmosphere Coeffs
float4 CONST_72        : register(c12); // Distance Fade Coeffs
float3 CONST_81        : register(c13); // Sky Base
float3 CONST_80        : register(c14); // Sky Alt
float3 CONST_79        : register(c15); // Sun Glow

sampler2D s_depth      : register(s0);
sampler2D s_fog_volume : register(s1);

struct PS_IN
{
    float3 v0   : TEXCOORD0; 
    float2 vPos : VPOS;    
};

float4 main(PS_IN i) : COLOR
{
    // --- 1. View Direction & Basic Factors ---
    float distSq = dot(i.v0, i.v0);
    float rcpDist = rsqrt(distSq);
    float3 viewDir = i.v0 * rcpDist;
    float skyDist = 1.0 / rcpDist;

    float horizon = saturate(viewDir.y);
    float sun = saturate(dot(viewDir, vSunDir));
    float2 atmFactors = saturate(float2(horizon, sun) * CONST_73.xy + CONST_73.zw);
    float distFade = saturate(skyDist * CONST_72.x + CONST_72.z);

    // ASM 8-9: Square the factors. (Horizon gets pow 4, Sun gets pow 4, Fade gets pow 2)
    float horizon4 = atmFactors.x * atmFactors.x;
    horizon4 *= horizon4;
    float sun4 = atmFactors.y * atmFactors.y;
    sun4 *= sun4;
    float distFade2 = distFade * distFade;

    // --- 2. Sky Colors ---
    float3 skyMix = lerp(CONST_81, CONST_80, horizon4);
    skyMix = lerp(skyMix, CONST_79, sun4);
    skyMix = lerp(skyMix, CONST_105.xyz, distFade2); // Uses squared distance!
    float3 final_rgb = skyMix * CONST_70.x;

    // --- 3. Scene Reconstruction ---
    // ASM 16: Ray from screen pos
    float3 screenRay = float3(i.vPos.xy * INV_FRUSTUM[1].xy + INV_FRUSTUM[1].zw, -1.0);
    float2 uv = i.vPos.xy * RT_PARAMS_BIAS.xy + RT_PARAMS_BIAS.zw;

    float sceneDepth = tex2Dlod(s_depth, float4(uv, 0, 0)).x;
    float4 fogVol = tex2Dlod(s_fog_volume, float4(uv, 0, 0));
    
    float fogDensity = fogVol.w * CONST_105.w;

    // --- 4. Depth Fog Factor ---
    float3 worldPos = screenRay * sceneDepth;
    float pixelDist = length(worldPos);

    // Occlusion: (PixelDist - SkyDist) * Scale + Bias
    float depthFog = saturate((pixelDist - skyDist) * CONST_102.y + CONST_102.x);
    float currentFog = fogDensity * depthFog;

    // --- 5. Height Fog Factor (The Intensity Fix) ---
    // ASM 29: dp4 r0.y, r1, c3
    float worldHeight = dot(float4(worldPos, 1.0), INVVIEW_XFORM[1]);

    // ASM 30: mad_sat_pp r0.yz, r0.y, c6.xxyw, c6.xzww
    float heightFadeA = saturate(worldHeight * CONST_104.x + CONST_104.z);
    float heightFadeB = saturate(worldHeight * CONST_104.y + CONST_104.w);

    // ASM 31-32: Select gradient and apply floor
    float selectedHeight = (-CONST_103.y >= 0.0) ? heightFadeB : heightFadeA;
    float finalHeightFade = max(CONST_103.z, selectedHeight);

    // ASM 33: Multiply depth and height
    float linearAlpha = saturate(currentFog * finalHeightFade);

    // --- 6. Cubic Smoothstep Alpha ---
    // ASM 34-36: 3x^2 - 2x^3
    
    float cubicAlpha = linearAlpha * linearAlpha * (3.0 - 2.0 * linearAlpha);
    
    return float4(final_rgb, cubicAlpha);
}