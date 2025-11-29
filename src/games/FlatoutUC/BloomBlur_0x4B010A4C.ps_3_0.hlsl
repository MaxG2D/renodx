#include "./shared.h"

// Bloom blur
float4 g_avSampleOffsets[16] : register(c116);
float4 g_avSampleWeights[16] : register(c132);
sampler2D s0 : register(s0);

float4 main(float2 vTexCoord : TEXCOORD0) : COLOR
{
    float4 f4AccumulatedColor = 0;

    // Loop through the 13 samples (i = 0 to 12)
    for (int i = 0; i < 13; i++)
    {
        if (RENODX_TONE_MAP_TYPE > 0.f) {
            g_avSampleOffsets[i] *= Custom_Bloom_BlurSize;
        }
        float2 f2SampleUV = vTexCoord + g_avSampleOffsets[i].xy;
        float4 f4SampleColor = tex2D(s0, f2SampleUV);
        f4AccumulatedColor += f4SampleColor * g_avSampleWeights[i];
    }
    return f4AccumulatedColor;
}
