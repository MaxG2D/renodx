#include "./shared.h"

// Skybox
sampler2D Tex0 : register(s0);
float4 g_PS_skyDomeColor : register(c34);
float4 g_PS_fogSkydomeColor : register(c45);
float4 g_PS_fogFarVariables : register(c47);

struct PS_INPUT
{
    float2 texcoord : TEXCOORD0; // v0.xy
    float3 texcoord1 : TEXCOORD1; // v1.xyz
};

float4 main(PS_INPUT input) : COLOR
{
    float4 r0, r1;
    
    float3 lumaWeights = float3(0.2126f, 0.7152f, 0.0722f);
    r0.x = dot(input.texcoord1.xyz, input.texcoord1.xyz);
    r0.x = rsqrt(r0.x);
    r0.x = input.texcoord1.y * r0.x - g_PS_fogFarVariables.x;
    r0.x = saturate(r0.x * g_PS_fogFarVariables.y);
    r1 = tex2D(Tex0, input.texcoord);
    r0.yzw = r1.xyz * g_PS_skyDomeColor.x + g_PS_skyDomeColor.z;
    if (Custom_Skybox_EnableBoost > 0 && RENODX_TONE_MAP_TYPE > 0.f) {
        float skyboxLuma = pow(dot(r0.yzw, lumaWeights), 1.5);
        float3 skyboxChroma = r0.yzw + (r0.yzw - skyboxLuma);
        float3 skyboxChromaDir = skyboxChroma / max(length(skyboxChroma), 1e-6) * Custom_Skybox_Saturation;
        r0.yzw *= lerp(skyboxLuma * Custom_Skybox_Intensity, skyboxChromaDir, saturate(Custom_Skybox_Curve * 0.5));
    }
    r1.xyz = g_PS_fogSkydomeColor.xyz - r0.yzw;
    r1.xyz = g_PS_fogFarVariables.z * r1.xyz + r0.yzw;
    r0.yzw = r0.yzw - r1.xyz;
    float3 finalColor = r0.x * r0.yzw + r1.xyz;
    return float4(finalColor, 1.0);
}