#include "./shared.h"

float4 GAMMA : register( c0 );
sampler2D s_tex : register( s0 );

float4 main(float2 texcoord : TEXCOORD) : COLOR
{
	float4 o;

	float4 r0;
	float3 r1;
	r0 = float4(1, 1, 1, 0) * texcoord.xyyx;
	r0 = tex2Dlod(s_tex, r0);
	r1.x = log2(r0.x);
	r1.y = log2(r0.y);
	r1.z = log2(r0.z);
	o.w = r0.w;
	r0.xyz = r1.xyz * GAMMA.y;
	o.x = exp2(r0.x);
	o.y = exp2(r0.y);
	o.z = exp2(r0.z);

	return o;
}
