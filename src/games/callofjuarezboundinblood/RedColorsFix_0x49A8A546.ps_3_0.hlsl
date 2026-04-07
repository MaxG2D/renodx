#include "./shared.h"

sampler2D s_tex : register( s0 );

float4 main(float2 texcoord : TEXCOORD) : COLOR
{
	float4 o;

	float4 r0;
	r0 = float4(1, 1, 1, 0) * texcoord.xyyx;
	r0 = saturate(tex2Dlod(s_tex, r0));
	r0.x = -r0.x + 1;
	r0.x = r0.x * r0.x;
	r0.y = r0.x * -2 + 3;
	r0.x = r0.x * r0.x;
	r0.x = r0.y * r0.x;
	r0.y = saturate(r0.x * r0.x);
	o.xyz = r0.x * float3(1, 0, 0) + r0.y; // Red tint
	//o.xyz = r0.x + r0.y;				   // We remove the tint completely. 
										   // Sadly, the effect is completely broken with texture upgrades :(
	o.w = r0.w;

	//return o;
	return float4(1, 1, 1, 1);
}
