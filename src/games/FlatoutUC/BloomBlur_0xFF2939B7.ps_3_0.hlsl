#include "./shared.h"

// Bloom blur
sampler2D s0 : register(s0);

// Arrays of 15 elements based on register size 15 in ASM header
float4 g_avSampleOffsets[15] : register(c116);
float4 g_avSampleWeights[15] : register(c132);

struct PS_INPUT
{
    float2 texcoord : TEXCOORD0; // v0.xy
};

float4 main(PS_INPUT input) : COLOR
{
    float4 finalColor = 0;

    // The ASM initializes with sample index 1 (c117), but mathematical order of summation doesn't matter.
    // It sums samples from index 0 to 14.
    for (int i = 0; i < 15; i++)
    {
        g_avSampleOffsets[i] *= Custom_Bloom_BlurSize;
        float2 sampleUV = input.texcoord + g_avSampleOffsets[i].xy;
        float4 colorSample = tex2D(s0, sampleUV);
        finalColor += colorSample * g_avSampleWeights[i];
    }

    return finalColor;
}