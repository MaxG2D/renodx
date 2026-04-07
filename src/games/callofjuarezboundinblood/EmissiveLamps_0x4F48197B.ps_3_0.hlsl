#include "./shared.h"
#include "./FakeHDRGain.hlsl"

float4 CONST_111 : register( c0 );
float4 CONST_70 : register( c1 );
sampler2D s_t05 : register( s5 );

struct PS_IN
{
	float2 texcoord : TEXCOORD;
	float texcoord6 : TEXCOORD6;
};

float4 main(PS_IN i) : COLOR
{
	float4 o;

	float4 r0;
	r0 = tex2D(s_t05, i.texcoord);
	r0.xyz = r0.xyz * CONST_111.xyz;
	r0.xyz = r0.xyz * i.texcoord6.x;
	//o.xyz = r0.xyz * CONST_70.x;
	o.xyz = (r0.xyz * 0.2) * CONST_70.x;
	o.xyz = pow(o.xyz, 2.2);
	o.w = 0;

	return o;
}
