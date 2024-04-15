#include "./shared.h"

// Sun Apr 14 14:06:54 2024
Texture2D<float4> t1 : register(t1);

Texture2D<float4> t0 : register(t0);

SamplerState s1_s : register(s1);

SamplerState s0_s : register(s0);

cbuffer cb2 : register(b2)
{
  float4 cb2[1];
}

cbuffer cb12 : register(b12)
{
  float4 cb12[41];
}



//  declarations
#define cmp -


void main(
  float4 v0 : SV_POSITION0,
  float2 v1 : TEXCOORD0,
  float2 w1 : TEXCOORD1,
  float4 v2 : COLOR0,
  float4 v3 : POSITION2,        //Not sure what to do about that
  float4 v4 : POSITION3,        //Not sure what to do about that
  out float4 o0 : SV_Target0,
  out float4 o1 : SV_Target1)
{
  float4 r0,r1;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyzw = t1.Sample(s1_s, w1.xy).xyzw;
  r1.xyzw = t0.Sample(s0_s, v1.xy).xyzw;
  r0.xyzw = -r1.xyzw + r0.xyzw;
  r0.xyzw = cb2[0].xxxx * r0.xyzw + r1.xyzw;
  r0.xyz = v2.xyz * r0.xyz;
  o0.w = (v2.w * r0.w) * injectedData.fxSunDiskAmount; // injectedData.fxSunDiskAmount
  r1.xyz = cb2[0].yyy * r0.xyz;
  r0.w = cmp(0 < cb2[0].y);
  o0.xyz = r0.www ? r1.xyz : r0.xyz;
  r0.x = dot(cb12[37].xyzw, v3.xyzw);
  r0.y = dot(cb12[38].xyzw, v3.xyzw);
  r0.z = dot(cb12[40].xyzw, v3.xyzw);
  r0.xy = r0.xy / r0.zz;
  r1.x = dot(cb12[31].xyzw, v4.xyzw);
  r1.y = dot(cb12[32].xyzw, v4.xyzw);
  r0.z = dot(cb12[34].xyzw, v4.xyzw);
  r0.zw = r1.xy / r0.zz;
  r0.xy = r0.xy + -r0.zw;
  o1.xy = float2(-0.5,0.5) * r0.xy;
  o1.zw = float2(1,1);
  return;
}