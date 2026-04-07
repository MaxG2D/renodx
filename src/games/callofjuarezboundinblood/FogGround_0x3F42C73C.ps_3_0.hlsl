#include "./shared.h"

float4 CONST_70 : register( c1 );
float4 CONST_72 : register( c3 );
float4 CONST_73 : register( c2 );
float4 CONST_79 : register( c6 );
float4 CONST_80 : register( c5 );
float4 CONST_81 : register( c4 );
sampler2D s_depth : register( s0 );
float3 vSunDir : register( c0 );

struct PS_IN
{
	float2 texcoord : TEXCOORD;
	float3 texcoord2 : TEXCOORD2;
};

float4 main(PS_IN i) : COLOR
{
	float4 o;

	float4 r0;
	float3 r1;
	float3 r2;
	r0 = float4(1, 1, 1, 0) * i.texcoord.xyyx;
	r0 = tex2Dlod(s_depth, r0);
	r0.xyz = r0.x * i.texcoord2.xyz;
	r1.xyz = normalize(-r0.xyz);
	r0.x = dot(r0.xyz, r0.xyz);
	r0.x = 1 / sqrt(r0.x);
	r0.x = 1 / r0.x;
	r0.z = saturate(r0.x * CONST_72.x + CONST_72.z);
	r2.x = saturate(r1.y);
	r2.y = saturate(dot(r1.xyz, vSunDir.xyz));
	r0.xy = saturate(r2.xy * CONST_73.xy + CONST_73.zw);
	r0.xyw = r0.xyz * r0.xyz;
	r0.z = r0.z * -r0.z + 1;
	r0.xy = r0.xy * r0.xy;
	o.w = r0.w;
	r1.xyz = CONST_81.xyz;
	r1.xyz = -r1.xyz + CONST_80.xyz;
	r1.xyz = r0.x * r1.xyz + CONST_81.xyz;
	r2.xyz = lerp(r1.xyz, CONST_79.xyz, r0.y);
	r0.xyw = r2.xyz * CONST_70.x;
	o.xyz = r0.z * r0.xyw;

	return o;
}
