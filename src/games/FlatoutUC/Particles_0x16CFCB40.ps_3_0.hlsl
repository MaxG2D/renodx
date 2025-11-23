#include "./shared.h"

// Particles
sampler2D Tex0          : register(s0);  // Diffuse Texture
sampler2D Tex1          : register(s1);  // Glow Texture
sampler2D SceneDepthMap : register(s12); // Scene Depth (Requires engine binding)

float4 g_PS_fogColor          : register(c44); 
float4 g_PS_textureGlowParams : register(c48); 
float4 g_PS_particleIntensity : register(c49); 
float4 g_PS_depthBufferScale  : register(c52); // Depth Decoding Constant (Requires engine binding)

struct PS_INPUT
{
    float2 uv           : TEXCOORD0; 
    float4 fogAndSoft   : TEXCOORD1; // x: FogFactor, y: Opacity, w: SoftParticleScale
    float3 screenProj   : TEXCOORD2; // xy: ScreenUV, z: PixelLinearDepth
    float4 vertexColor  : TEXCOORD3; 
};

float4 main(PS_INPUT input) : COLOR
{
    // --- 1. GLOW & DIFFUSE CALCULATION ---
    float4 glowSample = tex2D(Tex1, input.uv); 
    // Calculate glow intensity curve
    float glowPower = pow(glowSample.a, g_PS_textureGlowParams.y * pow(Custom_Particles_Glow_Contrast, 5));
    float glowFactor = (glowPower * g_PS_particleIntensity.x * g_PS_textureGlowParams.x * pow(Custom_Particles_Glow, 5)) + 1.0;  
    float3 glowColor = glowSample.rgb * glowFactor; 
    // Apply Fog Inverse to Glow
    float fogInverse = 1.0 - input.fogAndSoft.x;
    glowColor *= fogInverse * glowSample.a;
    float4 diffuseSample = tex2D(Tex0, input.uv);
    float4 tintedDiffuse = diffuseSample * input.vertexColor;
    float3 foggedDiffuse = lerp(tintedDiffuse.rgb, g_PS_fogColor.rgb, input.fogAndSoft.x);
    float3 finalDiffuse = foggedDiffuse * tintedDiffuse.a;
    float4 combinedColor;
    combinedColor.rgb = glowColor + finalDiffuse;
    combinedColor.a   = tintedDiffuse.a; 

    // --- 2. SOFT PARTICLE DEPTH FADE (FIXED LOGIC) ---
    float depthSample = tex2D(SceneDepthMap, input.screenProj.xy).r;  
    // Reconstruct linear Z/W from the depth map sample 
    float sceneDepth = 1.0 / (depthSample * g_PS_depthBufferScale.x + g_PS_depthBufferScale.y);
    // Calculate depth difference
    float depthDiff = sceneDepth - input.screenProj.z;
    float softFactor = saturate(depthDiff * input.fogAndSoft.w);
    float finalFade = softFactor * input.fogAndSoft.y;
    // --- 3. FINAL OUTPUT ---
    combinedColor *= finalFade; 
    combinedColor.rgb *= g_PS_particleIntensity.y;

    return float4(combinedColor.rgb, combinedColor.a);
}