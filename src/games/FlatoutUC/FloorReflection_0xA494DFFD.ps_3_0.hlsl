#include "./shared.h"
#include "./FakeHDRGain.h"

// --- Constants and Resources ---

// Fresnel parameters for the reflective surface (c10)
float4 g_PS_windowStaticFresnel : register(c10);    // .x=Min, .y=Max, .z=Power, .w=SpecularPower
float4 g_PS_skyDomeColor : register(c34);           // .w is sky/reflection intensity factor
float4 g_PS_diffuseLightColor : register(c37);
float4 g_PS_lightDirWorld : register(c39);
float4 g_PS_specularLightColor : register(c41);
float4 g_PS_windowEmitColor : register(c51);

sampler2D Tex0 : register(s0); // Base texture (Diffuse/Albedo)
samplerCUBE Tex1 : register(s1); // Environment Cubemap

// Constant c0
static const float ONE = 1.0f;
static const float ZERO = 0.0f;
static const float NEG_HALF = -0.5f;

// --- Input Structure ---
struct PS_INPUT
{
    float2 Texcoord0  : TEXCOORD0; // v0.xy: Base UV
    float3 ViewVector : TEXCOORD1; // v1.xyz: Eye-to-Surface Vector (V)
    float3 Normal     : TEXCOORD2; // v2.xyz: Surface Normal (N)
    float4 Diffuse    : TEXCOORD3; // v3.xyzw: Vertex Diffuse Color/Mask
    float3 ReflectDir : TEXCOORD4; // v4.xyz: Reflection Vector (R_env)
};

// --- Main Shader Function ---
float4 main(PS_INPUT input) : COLOR
{
    // --- Setup & Initial Samples ---

    // Sample the environment cubemap for the base reflection color
    float4 reflectionColorRaw = texCUBE(Tex1, input.ReflectDir.xyz);
    float3 worldNormal = normalize(input.Normal.xyz);
    float3 viewVector = normalize(input.ViewVector.xyz);
    float4 baseTexture = tex2D(Tex0, input.Texcoord0.xy);


    // --- Diffuse Lighting Calculation ---

    // Calculate N dot L (Normal dot LightDir) and clamp (r0.w)
    float NdotL_Clamped = saturate(dot(worldNormal, g_PS_lightDirWorld.xyz));
    float3 diffuseLightIntensity = NdotL_Clamped * g_PS_diffuseLightColor.xyz;
    float3 modulatedDiffuse = diffuseLightIntensity * input.Diffuse.w + input.Diffuse.xyz;
    float3 finalDiffuseColor = modulatedDiffuse * baseTexture.xyz; // r2.xyz

    // --- Reflection/Diffuse Prep for Lerp ---

    // (Reflection * SkyFactor)
    float3 weightedReflection = reflectionColorRaw.xyz * g_PS_skyDomeColor.w;
    // Lerp: B - A (WeightedReflection - FinalDiffuse)
    float3 lerpDifference = weightedReflection - finalDiffuseColor; // r0.xyz = r0.xyz * c34.w - r2.xyz


    // --- Fresnel Factor Calculation ---

    // Calculate N dot V
    float NdotV = dot(viewVector, worldNormal);
    // Fresnel Base: (1.0 - abs(N dot V))
    float fresnelBase = ONE - abs(NdotV);
    // Apply power: (1.0 - abs(N dot V))^Power
    float fresnelPowerTerm = pow(fresnelBase, g_PS_windowStaticFresnel.z);
    float fresnelFactor = lerp(g_PS_windowStaticFresnel.x, g_PS_windowStaticFresnel.y, fresnelPowerTerm);

    // --- Reflection Blending ---

    // Reflection Fade Mask: (Texture Alpha - 0.5) * 2, then clamped.
    // The ASM's `add_sat r1.x, r3.w, r3.w` translates to saturate(r3.w + r3.w).
    // The provided manual decompilation had an error here. It should be:
    float reflectionFadeMask = saturate(baseTexture.w * 2.0f); // r1.x = saturate(r3.w + r3.w)
    float finalReflBlendFactor = fresnelFactor * reflectionFadeMask;

    // Finalize the Diffuse/Reflection blend using the Lerp structure from instructions 7 & 19:
    float3 combinedDiffuseRefl = finalDiffuseColor + finalReflBlendFactor * lerpDifference; // r0.xyz

    // --- Specular Lighting Calculation ---

    // Normalize the reflection direction for the specular calculation
    float3 specularVector = normalize(input.ReflectDir.xyz);
    // Calculate R dot L
    float RdotL = dot(specularVector, g_PS_lightDirWorld.xyz);
    // Specular Term: (R dot L)^SpecularPower
    float specularTerm = pow(RdotL, g_PS_windowStaticFresnel.w);
    float specularIntensity = finalReflBlendFactor * specularTerm;
    specularIntensity = (input.Diffuse.w > ZERO) ? ZERO : specularIntensity;
    float3 finalLightingColor = combinedDiffuseRefl + specularIntensity * g_PS_specularLightColor.xyz; // r0.xyz


    // --- Alpha & Emissive Calculation ---
    float4 outputColor;
    outputColor.w = saturate(reflectionFadeMask * fresnelFactor + specularIntensity);
    float opacityFactor = ONE - fresnelFactor;
    float emissiveAlphaPrep = baseTexture.w + NEG_HALF;
    float emissiveMask = saturate(emissiveAlphaPrep * 2.0f); // r1.x

    // Calculate Emissive Color: TextureRGB * EmissiveLightColor
    float3 emissiveColor = baseTexture.xyz * g_PS_windowEmitColor.xyz;  // r1.yzw
    if (RENODX_TONE_MAP_TYPE > 0) {
      emissiveColor = ApplyFakeHDRGain(emissiveColor, pow(Custom_Emissives_Glow, 15), pow(Custom_Emissives_Glow_Contrast, 15), Custom_Emissives_Glow_Saturation);
    }
    float finalEmissiveBlendFactor = opacityFactor * emissiveMask;

    // Add Emissive Color to the final color:
    outputColor.xyz = finalLightingColor + finalEmissiveBlendFactor * emissiveColor;

    return outputColor;
}