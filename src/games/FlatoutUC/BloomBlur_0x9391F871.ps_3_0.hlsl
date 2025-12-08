#include "./shared.h"

// Bloom blur

// The g_avSampleOffsets array is mapped to constant registers c116 through c131.
float4 g_avSampleOffsets[16] : register(c116);
sampler2D s0 : register(s0);

// This is the weight used for the final division/multiplication to get the average.
static const float WEIGHT = 0.0625;

float4 main(float2 texcoord : TEXCOORD) : COLOR
{
    float4 accumulatedColor = tex2D(s0, g_avSampleOffsets[0].xy + texcoord.xy);

    // Loop through the remaining 15 samples (indices 1 to 15).
    for (int i = 1; i < 16; i++)
    {
		if (RENODX_TONE_MAP_TYPE > 0.f) {
		g_avSampleOffsets[i] *= Custom_Bloom_BlurSize;
		}
        float2 sampleUV = g_avSampleOffsets[i].xy + texcoord.xy;
        float4 sampleColor = tex2D(s0, sampleUV);
        accumulatedColor += sampleColor;
    }

    return accumulatedColor * WEIGHT;
}