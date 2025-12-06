#include "./shared.h"
#include "./FakeHDRGain.h"

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
    float3 C_sky = r0.yzw;                    // Color_sky
    float3 C_fog = g_PS_fogSkydomeColor.xyz;  // Color_fog
    float K = g_PS_fogFarVariables.z;         // Scattering/Extinction factor

    // The 'pre-fogged' color
    float3 C_prime_sky = K * (C_fog - C_sky) + C_sky;
    float3 finalColor = r0.x * (C_sky - C_prime_sky) + C_prime_sky;

    if (Custom_Skybox_EnableBoost > 0 && RENODX_TONE_MAP_TYPE > 0.f) 
    {
        /* Old Boost Code
        float finalLuma = dot(finalColor, lumaWeights);
        float L_min = 0.0f;
        float L_max = 32.0f;
        float boostIntensity = smoothstep(L_min, L_max, finalLuma);
        float skyboxLuma = pow(dot(finalColor, lumaWeights), 2.2);
        float3 skyboxChroma = finalColor + (finalColor - skyboxLuma);
        float3 skyboxChromaDir = max(0.f, skyboxChroma / max(length(skyboxChroma), 1e-6) * Custom_Skybox_Saturation * 2);
        float3 boostMultiplier_Direction = lerp(skyboxLuma, skyboxChromaDir, saturate(Custom_Skybox_Curve * 0.5));
        float3 fullyBoostedColor = finalColor * (boostMultiplier_Direction * 125.0f * Custom_Skybox_Intensity);
        finalColor = lerp(finalColor, fullyBoostedColor, boostIntensity);
        */
        finalColor = ApplyFakeHDRGain(finalColor, pow(Custom_Skybox_Intensity, 10), pow(Custom_Skybox_Curve, 10), Custom_Skybox_Saturation);
    }

    return float4(finalColor, 1.0);
}