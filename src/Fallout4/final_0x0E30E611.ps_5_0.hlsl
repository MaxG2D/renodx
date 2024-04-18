#include "./shared.h"

// Sun Apr 14 14:06:35 2024
Texture2D<float4> t6 : register(t6);

Texture2D<float4> t5 : register(t5);

Texture2D<float4> t4 : register(t4);

Texture2D<float4> t3 : register(t3);

Texture2D<float4> t0 : register(t0);

SamplerState s6_s : register(s6);

SamplerState s5_s : register(s5);

SamplerState s4_s : register(s4);

SamplerState s3_s : register(s3);

SamplerState s0_s : register(s0);

cbuffer cb2 : register(b2)
{ 
  float4 cb2[1];
}


//  declarations
#define cmp -


void main(
  float4 v0 : SV_POSITION0,
  out float4 o0 : SV_Target0)
{
  float4 r0,r1,r2,r3;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xy = cb2[0].xy * v0.xy;
  r1.xyzw = t0.SampleLevel(s0_s, r0.xy, 0).xyzw;
  r0.z = t3.SampleLevel(s3_s, r0.xy, 0).w;
  r2.xyz = t5.SampleLevel(s5_s, r0.xy, 0).xyz;
  r2.xyz = r2.xyz * injectedData.fxSunDirectionalAmount * r1.xyz; // injectedData.fxSunDirectionalAmount
  r3.xyz = t4.Sample(s4_s, r0.xy).xyz;
  r1.xyz = float3(3,3,3) * r2.xyz;
  r0.z = r0.z * 255 + -5;
  r0.z = cmp(abs(r0.z) >= 0.25);
  if (r0.z != 0) {
    r0.xyz = t6.SampleLevel(s6_s, r0.xy, 0).xyz;
    r0.xyz = r0.xyz * injectedData.fxSpecularAmount + r3.xyz; // injectedData.fxSpecularAmount
    r1.xyz = r2.xyz * float3(3,3,3) + r0.xyz;
  }
  o0.xyzw = r1.xyzw;
  return;
}