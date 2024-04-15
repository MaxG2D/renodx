#include "../common/color.hlsl"

// Sun Apr 14 14:34:39 2024
Texture2D<float4> t3 : register(t3);

Texture2D<float4> t2 : register(t2);

Texture2D<float4> t1 : register(t1);

Texture2D<float4> t0 : register(t0);

SamplerState s3_s : register(s3);

SamplerState s2_s : register(s2);

SamplerState s1_s : register(s1);

SamplerState s0_s : register(s0);

cbuffer cb2 : register(b2)
{
  float4 cb2[5];
}




//  declarations
#define cmp -


void main(
  float4 v0 : SV_POSITION0,
  float2 v1 : TEXCOORD0,
  out float4 o0 : SV_Target0)
{
  float4 r0,r1,r2,r3;
  uint4 bitmask, uiDest;
  float4 fDest;

					
			 
		   
  r0.xyz = t1.Sample(s1_s, v1.xy).xyz;
  r0.w = t3.Sample(s3_s, v1.xy).w;
  r0.w = r0.w;

  r1.xy = cb2[4].zw * v1.xy;
  r1.xyz = t0.Sample(s0_s, r1.xy).xyz;
  r0.w = t2.Sample(s2_s, v1.xy).x;
  r1.w = r0.w;
  r0.xyz = r1.xyz + r0.xyz;
  r0.xyz = r0.xyz;
  r1.xyz = r0.xyz;
  r2.xyz = r0.xyz;
  r3.xy = cb2[1].ww;
  r1.x = cb2[1].w;
  r1.x = r1.x -r3.y;
  r1.x = 1;
  r1.xyz = r1.xxx * r0.xyz;
  r1.w = 0;
  r1.xyzw = r1.xyzw;
  r1.xyzw = cb2[2].xxxx * r1.xyzw;
  r2.xyzw = cb2[3].xyzw + -r1.xyzw;
  r1.xyzw = cb2[3].wwww * r2.xyzw + r1.xyzw;
  r1.xyzw = cb2[2].wwww * r1.xyzw;
  o0.xyzw = cb2[2].zzzz * r1.xyzw;
  return;
}