#include "./shared.h"

float4 CONST_100[4] : register( c0 );
sampler2D s_t00 : register( s0 );

struct PS_IN
{
	float4 texcoord : TEXCOORD;
	float4 texcoord1 : TEXCOORD1;
	float4 texcoord2 : TEXCOORD2;
	float4 texcoord3 : TEXCOORD3;
};

float4 main(PS_IN i) : COLOR
{
	float4 o;

	float4 r0;
	float4 r1;
	r0 = tex2D(s_t00, i.texcoord.zwzw);
	r0 = r0 * CONST_100[0].w;
	r1 = tex2D(s_t00, i.texcoord);
	r0 = r1 * CONST_100[0].w + r0;
	r1 = tex2D(s_t00, i.texcoord1);
	r0 = r1 * CONST_100[1].w + r0;
	r1 = tex2D(s_t00, i.texcoord1.zwzw);
	r0 = r1 * CONST_100[1].w + r0;
	r1 = tex2D(s_t00, i.texcoord2);
	r0 = r1 * CONST_100[2].w + r0;
	r1 = tex2D(s_t00, i.texcoord2.zwzw);
	r0 = r1 * CONST_100[2].w + r0;
	r1 = tex2D(s_t00, i.texcoord3);
	r0 = r1 * CONST_100[3].w + r0;
	r1 = tex2D(s_t00, i.texcoord3.zwzw);
	o = r1 * CONST_100[3].w + r0;

	return o;
}
