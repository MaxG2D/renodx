#include "./shared.h"
#include "./FakeHDRGain.hlsl"

float4 CONST_102 : register(c0); 
float4 CONST_104 : register(c1); 
float4 CONST_70  : register(c4); 
float4 CONST_72  : register(c6); 
float4 CONST_73  : register(c5); 
float4 CONST_79  : register(c9); 
float4 CONST_80  : register(c8); 
float4 CONST_81  : register(c7); 
float4 RENDER_TARGET_PARAMS_BIAS : register(c3);
sampler2D s_clouds_noise_a : register(s1);
sampler2D s_clouds_noise_b : register(s2);
sampler2D s_clouds_pp : register(s0);
float3 vSunDir : register(c2);

struct PS_IN
{
    float3 texcoord : TEXCOORD; // v0
    float4 texcoord1 : TEXCOORD1; // v1
    float2 vPos : VPOS;
};

float4 main(PS_IN i) : COLOR
{
    // Noise sampling and combination
    float4 nA = tex2D(s_clouds_noise_a, i.texcoord1.xy);
    float4 nB = tex2D(s_clouds_noise_b, i.texcoord1.zw);
    float3 noiseDistortion = (nA.wyy + nB.wyy) * CONST_104.x + CONST_104.y;

    // Screen UV and Distance calculation
    float2 screenUV = i.vPos.xy * RENDER_TARGET_PARAMS_BIAS.xy + RENDER_TARGET_PARAMS_BIAS.zw;
    float distSq = dot(i.texcoord, i.texcoord);
    float rcpDist = rsqrt(distSq);
    float dist = 1.0 / rcpDist;
    
    float2 finalUV = noiseDistortion.xy * rcpDist + screenUV;

    // Initial Distance Fade (Fog)
    float distanceFade = saturate(dist * CONST_72.x + CONST_72.z);

    // Cloud Texture Sample
    float4 cloudTex = tex2Dlod(s_clouds_pp, float4(finalUV, 0, 0));

    // Normalization and Sun/Horizon Dots
    float3 viewDir = normalize(-i.texcoord);
    float3 dotFactors = saturate(float3(viewDir.y, dot(viewDir, vSunDir), 0));

    // Apply Atmosphere Multipliers
    float3 atmosphere = saturate(dotFactors.xyz * CONST_73.xyz + CONST_73.zww);

    // mul r0.xyz, r0, r0 (Squares everything, including distanceFade)
    atmosphere.xy *= atmosphere.xy;
    distanceFade *= distanceFade; 
    
    // mul r0.xy, r0, r0 (Squares ONLY horizon/sun, NOT distanceFade)
    atmosphere.xy *= atmosphere.xy; 

    // Sky Color Calculations
    float3 skyBase = lerp(CONST_81.xyz, CONST_80.xyz, atmosphere.x);
    float3 skyFinal = lerp(skyBase, CONST_79.xyz, atmosphere.y);

    // Manual Lerp Composition
    // Output = Atmosphere + (DistanceFade * (Cloud * Gain - Atmosphere))
    float3 cloudIntensity = cloudTex.xyz * CONST_102.xyz;
    float3 diff = abs(cloudIntensity - skyFinal);
    float3 finalRGB = distanceFade * diff + skyFinal;

    // ASM 24: Global Multiplier
    float4 o;
    finalRGB = FakeHDRGain::Apply(finalRGB, CUSTOM_CLOUDS_GLOW, CUSTOM_CLOUDS_GLOW_CONTRAST, CUSTOM_CLOUDS_GLOW_SATURATION);
    o.xyz = max(finalRGB * CONST_70.x, 0.f);
    o.w = max(cloudTex.a, 0.f);

    return o;
}