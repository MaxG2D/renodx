#include "./shared.h"

sampler2D s_bck : register( s0 );

float4 main(float3 texcoord : TEXCOORD) : COLOR
{
	float4 o;

	float4 r0;
	r0 = tex2D(s_bck, texcoord);
	o = max(r0 * texcoord.z, 0.f);
	o = pow(o, 1/2.2);

	return o;
}
