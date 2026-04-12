#include "./shared.h"

// Bloom blur 2
float4 g_avSampleOffsets[16] : register(c116);
float4 g_avSampleWeights[16] : register(c132);
sampler2D s0 : register(s0);

float4 main(float2 uv : TEXCOORD0) : COLOR
{
    float blurScale = (RENODX_TONE_MAP_TYPE > 0.f) ? Custom_Bloom_BlurSize : 1.0;
    float4 f4AccumulatedColor = 0;

    // Optional: normalize the first 13 weights
    float weightSum = 0.0;
    [unroll]
    for (int w = 0; w < 13; w++)
        weightSum += g_avSampleWeights[w].x;
    float invWeight = (weightSum > 0.0) ? (1.0 / weightSum) : 1.0;

    // Loop through 13 samples
    [unroll]
    for (int i = 0; i < 13; i++)
    {
      float2 offsetUV = g_avSampleOffsets[i].xy * blurScale;  // local copy
      float4 f4SampleColor = tex2D(s0, uv + offsetUV);
        f4AccumulatedColor += f4SampleColor * g_avSampleWeights[i].x;
    }

    return f4AccumulatedColor * invWeight;
}

/* Vanilla
float4 f4AccumulatedColor = 0;
// Loop through the 13 samples (i = 0 to 12) for (int i = 0; i < 13; i++)
if (RENODX_TONE_MAP_TYPE > 0.f) {
    g_avSampleOffsets[i] *= Custom_Bloom_BlurSize;
}
float2 f2SampleUV = uv + g_avSampleOffsets[i].xy; 
float4 f4SampleColor = tex2D(s0, f2SampleUV);
f4AccumulatedColor += f4SampleColor * g_avSampleWeights[i]; 

return f4AccumulatedColor;
*/