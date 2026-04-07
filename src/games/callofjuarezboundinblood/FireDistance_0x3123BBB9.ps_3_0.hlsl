#include "./shared.h"
#include "./FakeHDRGain.hlsl"

sampler2D s_t00 : register( s0 );

struct PS_IN
{
	float2 texcoord : TEXCOORD;
	float3 texcoord7 : TEXCOORD7;
};

float4 main(PS_IN i) : COLOR
{
	float4 o;

	float4 r0;
	r0 = tex2D(s_t00, i.texcoord);
	r0.xyz = r0.xyz * r0.xyz;
	o.xyz = r0.xyz * i.texcoord7.xyz * 5;
	o.w = 0;

	return o;
}
