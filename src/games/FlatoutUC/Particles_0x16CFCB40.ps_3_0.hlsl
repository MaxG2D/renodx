#include "./shared.h"

// Particles
sampler2D DiffuseTexture : register(s0);  // Tex0
sampler2D GlowTexture    : register(s1);  // Tex1
sampler2D DepthTexture   : register(s12); // SceneDepthMap

float4 g_FogColor         : register(c44);
float4 g_GlowParams       : register(c48); // x: Intensity Mult, y: Power
float4 g_GlobalIntensity  : register(c49); // x: Glow Base, y: Final Mult
float4 g_DepthDecode      : register(c52); // x: Scale, y: Bias (Reconstruct LinearZ)

struct PS_INPUT
{
    float2 uv           : TEXCOORD0; // Texture Coordinates
    float4 fogAndSoft   : TEXCOORD1; // x: FogFactor, y: Opacity, w: SoftParticleScale
    float3 screenProj   : TEXCOORD2; // xy: ScreenUV, z: PixelLinearDepth
    float4 vertexColor  : TEXCOORD3; // Particle Color
};

float4 main(PS_INPUT input) : COLOR
{
    // 1. Calculate Glow Component
    // ---------------------------
    float4 glowSample = tex2D(GlowTexture, input.uv);

    // Calculate glow intensity curve: (Alpha ^ Power) * IntensityMult * BaseIntensity + 1.0
    float glowPower = pow(glowSample.a, g_GlowParams.y * pow(Custom_Particles_Glow_Contrast, 5));
    float glowFactor = (glowPower * g_GlobalIntensity.x * g_GlowParams.x * pow(Custom_Particles_Glow, 5)) + 1.0;
    
    // Apply glow factor and premultiply alpha logic (masked by alpha)
    float3 glowColor  = glowSample.rgb * glowFactor;
    
    // Apply Fog Inverse to Glow (Glow fades as fog increases?)
    float fogInverse  = 1.0 - input.fogAndSoft.x;
    glowColor         *= fogInverse * glowSample.a;

    // 2. Calculate Diffuse Component
    // ------------------------------
    float4 diffuseSample = tex2D(DiffuseTexture, input.uv);
    float4 tintedDiffuse = diffuseSample * input.vertexColor; 
    // Apply Fog: Lerp(TintedDiffuse, FogColor, FogFactor)
    float3 foggedDiffuse = lerp(tintedDiffuse.rgb, g_FogColor.rgb, input.fogAndSoft.x);   
    // Apply Alpha (Premultiply)
    float3 finalDiffuse  = foggedDiffuse * tintedDiffuse.a;

    // 3. Combine Layers
    // -----------------
    // Combine Glow (RGB) + Diffuse (RGB). 
    // Alpha is purely from Diffuse channel (Glow doesn't contribute to opacity here).
    float4 combinedColor;
    combinedColor.rgb = glowColor + finalDiffuse;
    combinedColor.a   = tintedDiffuse.a;

    // 4. Soft Particle Depth Fade
    // ---------------------------
    float depthSample = tex2D(DepthTexture, input.screenProj.xy).r;
    float sceneDepth = 1.0 / (depthSample * g_DepthDecode.x + g_DepthDecode.y);
    float depthDiff = sceneDepth - input.screenProj.z;
    float softFactor = saturate(depthDiff * input.fogAndSoft.w);
    float finalFade = softFactor * input.fogAndSoft.y;

    // 5. Final Output
    // ---------------
    combinedColor *= finalFade;
    combinedColor.rgb *= g_GlobalIntensity.y;

    return combinedColor;
}