#include "./shared.h"
#include "./FakeHDRGain.hlsl"

float4 main(float4 texcoord : TEXCOORD) : COLOR
{
	float4 o;

	float r0;
	r0.x = texcoord.w * texcoord.w; // Softness
	o = r0.x * texcoord; // Chromatic shape
	o = o * 2;

	return max(0.f, min(65000, o));
}
