#include "./shared.h"

float4 CONST : register( c0 );
sampler2D sTex0 : register( s0 );

float4 main(float2 texcoord : TEXCOORD) : COLOR
{
	float4 o;

	float4 r0;
	r0 = tex2D(sTex0, texcoord);
	o.xyz = r0.xyz + CONST.xyz;
	o.w = r0.w * CONST.w;

	return o;
}
