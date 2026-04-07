#include "./shared.h"
#include "./FakeHDRGain.hlsl"

float4 CONST_70 : register( c1 );
float4 CONST_73 : register( c2 );
float4 CONST_79 : register( c5 );
float4 CONST_80 : register( c4 );
float4 CONST_81 : register( c3 );
float3 vSunDir : register( c0 );

float4 main(float3 texcoord : TEXCOORD) : COLOR
{
	float4 o;

	float4 r0;
	float4 r1;
	r0.xyz = normalize(-texcoord.xyz);
	r1.x = saturate(r0.y);
	r1.y = saturate(dot(r0, vSunDir));
	r0.xy = saturate(r1 * CONST_73 + CONST_73.zwzw);
	r0.xy = r0 * r0;
	r0.xy = r0 * r0;
	r1.xyz = CONST_81;
	r1.xyz = -r1.xyz + CONST_80;
	r0.xzw = r0.x * r1.xyz + CONST_81.xyz * 3;
	r1.xyz = lerp(r0.xzww, CONST_79, r0.y);
	o.xyz = max(r1.xyz * CONST_70.x * 1, 0.f);
	o.w = max(0, 0.f);

	return o;
}
