#include "./shared.h"

// Bloom blur 1

// The g_avSampleOffsets array is mapped to constant registers c116 through c131.
float4 g_avSampleOffsets[16] : register(c116);
sampler2D s0 : register(s0);

// This is the weight used for the final division/multiplication to get the average.
static const float WEIGHT = 0.0625;
static const float4 FakeWeights16[16] =
{
	float4(0.0882353, 0, 0, 0), float4(0.0830000, 0, 0, 0),
	float4(0.0720000, 0, 0, 0), float4(0.0570000, 0, 0, 0),
	float4(0.0400000, 0, 0, 0), float4(0.0260000, 0, 0, 0),
	float4(0.0150000, 0, 0, 0), float4(0.0080000, 0, 0, 0),
	float4(0.0080000, 0, 0, 0), float4(0.0150000, 0, 0, 0),
	float4(0.0260000, 0, 0, 0), float4(0.0400000, 0, 0, 0),
	float4(0.0570000, 0, 0, 0), float4(0.0720000, 0, 0, 0),
	float4(0.0830000, 0, 0, 0), float4(0.0882353, 0, 0, 0)
};

float4 main(float2 uv: TEXCOORD0) : COLOR
{
	float blurScale = (RENODX_TONE_MAP_TYPE > 0.f) ? Custom_Bloom_BlurSize : 1.0;

	float weightSum = 0.0;
	[unroll]
	for (int j = 0; j < 16; j++)
	weightSum += FakeWeights16[j].x;

	float invWeightSum = 1.0 / weightSum;

	float4 accum = 0.0;
	[unroll]
	for (int k = 0; k < 16; k++)
	{
	float2 offset = g_avSampleOffsets[k].xy * blurScale;
	accum += tex2D(s0, uv + offset) * FakeWeights16[k].x;
	}

	return accum * invWeightSum;
}

/* Vanilla
{
float4 accumulatedColor = tex2D(s0, g_avSampleOffsets[0].xy + uv.xy);

// Loop through the remaining 15 samples (indices 1 to 15).
for (int i = 1; i < 16; i++)
    {
  if (RENODX_TONE_MAP_TYPE > 0.f) {
    g_avSampleOffsets[i] *= Custom_Bloom_BlurSize;
  }
  float2 sampleUV = g_avSampleOffsets[i].xy + uv.xy;
  float4 sampleColor = tex2D(s0, sampleUV);
  accumulatedColor += sampleColor;
}

return accumulatedColor * WEIGHT;
*/