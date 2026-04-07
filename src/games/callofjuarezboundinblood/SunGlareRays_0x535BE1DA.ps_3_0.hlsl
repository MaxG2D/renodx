#include "./shared.h"
#include "./FakeHDRGain.hlsl"

float4 CONST_5 : register( c0 );
sampler2D s_bck : register( s0 );
sampler2D s_msk : register( s1 );

struct PS_IN
{
	float4 texcoord : TEXCOORD;
	float4 texcoord1 : TEXCOORD1;
};

float4 main(PS_IN i) : COLOR
{
	float4 o;

	float4 r0;
	float4 r1;
	r0 = tex2D(s_msk, i.texcoord1);
	r1 = tex2D(s_msk, i.texcoord1.zwzw);
	r0.x = r0.y * r1.w;
	r0.xyz = r0.x * CONST_5.xyz * 0.2; // Color
	r1 = tex2D(s_bck, i.texcoord);
	r1 = r1.xyzx * float4(1, 1, 1, 0) + float4(0, 0, 0, 1);
	r0.w = dot(r1, i.texcoord.zzzw) * 0.2; // Amount
	//o.xyz = r0.xyz * r0.w;
	o.xyz = r0.xyz * r0.w;
	o.w = 0.2; // Vanilla

	return o;
}
