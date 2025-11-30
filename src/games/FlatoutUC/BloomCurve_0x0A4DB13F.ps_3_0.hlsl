#include "./shared.h"

// Bloom brightpass threshold
sampler2D SceneTexture : register(s0);
sampler2D ExposureTexture  : register(s1); // (1x1 or LUT sample)

// Bloom Curve Parameters:
// x: Threshold
// y: Intensity below threshold
// z: Intensity above threshold (slope)
float4 g_BloomCurve : register(c111);

struct PS_INPUT
{
    float2 texcoord : TEXCOORD0;
};

float4 main(PS_INPUT input) : COLOR
{
    // Constants
    const float3 VANILLA_WEIGHTS = float3(0.333f, 0.333f, 0.333f);
    const float3 LUMA_WEIGHTS = float3(0.2126f, 0.7152f, 0.0722f);
    const float  EPSILON      = 0.001f;
    const float  TINT_UV_X    = 0.03125f; // Center of 1st pixel in 32px texture

    // 1. Sample Textures
    // Sample the tint/exposure factor from the second texture (1D lookup)
    float4 exposureSample = tex2D(ExposureTexture, float2(TINT_UV_X, 0.0f));  
    // Sample the main scene color
    float4 sceneColor = tex2D(SceneTexture, input.texcoord);

    // 2. Apply Tint
    float3 tintedColor = sceneColor.rgb * exposureSample.r;

    // 3. Calculate Luminance
    // Using a uniform weight (0.333) approximation + epsilon to prevent div-by-zero
    float luma;
    //if (RENODX_TONE_MAP_TYPE > 0.f) {
    //  luma = dot(tintedColor, LUMA_WEIGHTS);
    //} else {
      luma = dot(tintedColor, VANILLA_WEIGHTS);
    //}
    luma += EPSILON;

    // 4. Bloom Curve Logic
    // The ASM implements a "Soft Knee" curve logic based on the threshold.
    float threshold;
    if (RENODX_TONE_MAP_TYPE > 0.f) {
      threshold = g_BloomCurve.x * pow(max(Custom_Bloom_Threshold, EPSILON), 3.3);
    } else {
      threshold = g_BloomCurve.x;
    }
    float intensityLow = g_BloomCurve.y;
    float intensityHigh = g_BloomCurve.z;

    float bloomFactor;

    if (luma >= threshold)
    {
        // Above Threshold: Linear slope logic
        // Value = (Luma - Threshold) * HighIntensity + LowIntensity
        bloomFactor = (luma - threshold) * intensityHigh + intensityLow;
    }
    else
    {
      // Below Threshold: Scaled fraction of logic
      // Value = (Luma * LowIntensity) / Threshold
      bloomFactor = (luma * max(intensityLow, EPSILON)) / threshold;
    }

    // 5. Reconstruct Color
    // Normalize the calculated bloom factor by the original luma 
    // to preserve the hue while adjusting brightness.
    // Final Color = (TintedColor / Luma) * BloomFactor
    
    float3 finalColor = tintedColor * (bloomFactor / luma);

    return float4(finalColor, sceneColor.a);
}