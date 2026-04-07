#include "./shared.h"

float4 CONST_101 : register( c0 );
sampler2D s_depth : register( s0 );

struct PS_IN
{
	float2 texcoord : TEXCOORD;
	float3 texcoord1 : TEXCOORD1;
	float3 texcoord2 : TEXCOORD2;
	float3 texcoord3 : TEXCOORD3;
	float3 texcoord4 : TEXCOORD4;
};

float4 main(PS_IN i) : COLOR
{
	float4 o;

	float4 r0;
	float4 r1;
	float4 r2;
	float4 r3;
	
	r0 = float4(1, 1, 1, 0) * i.texcoord1.xzzx;
	r0 = tex2Dlod(s_depth, r0);
	r1 = float4(1, 1, 1, 0) * i.texcoord1.yzzx;
	r1 = tex2Dlod(s_depth, r1);
	r0.y = r1.x;
	
	r1 = float4(1, 1, 1, 0) * i.texcoord2.xzzx;
	r1 = tex2Dlod(s_depth, r1);
	r2 = float4(1, 1, 1, 0) * i.texcoord2.yzzx;
	r2 = tex2Dlod(s_depth, r2);
	r1.y = r2.x;
	
	r0.xy = r0.xy + r1.xy;
	
	r1 = float4(1, 1, 1, 0) * i.texcoord3.xyyx;
	r1 = tex2Dlod(s_depth, r1);
	r1.z = r1.x;
	
	r2 = float4(1, 1, 1, 0) * i.texcoord3.xzzx;
	r2 = tex2Dlod(s_depth, r2);
	r1.w = r2.x;
	
	r2 = float4(1, 1, 1, 0) * i.texcoord4.xyyx;
	r2 = tex2Dlod(s_depth, r2);
	r2.z = r2.x;
	
	r3 = float4(1, 1, 1, 0) * i.texcoord4.xzzx;
	r3 = tex2Dlod(s_depth, r3);
	r2.w = r3.x;
	
	r0.zw = r1.zw + r2.zw; 
	
	r1 = float4(1, 1, 1, 0) * i.texcoord.xyyx;
	r1 = tex2Dlod(s_depth, r1);
	r0 = r0 * 0.5 + -r1.x;
	r1.x = 1 / r1.x;
	r0 = abs(r0) * r1.x + -0.01;
	r0 = (r0 >= 0) ? 1 : 0;
	r0.xy = r0.zw * r0.xy;

	// Combine axes with a weight. 0.3 is vanilla.
	r0.x = dot(r0.xy, float2(0.3 * CUSTOM_AA_BLUR_STRENGTH, 0.3 * CUSTOM_AA_BLUR_STRENGTH)); 
	
	o.z = max(CONST_101.w, r0.x);
	o.xyw = 0.5;

	return o;
}