// Thu Apr 18 21:35:07 2024
Texture2D<float4> t3 : register(t3);

Texture2D<float4> t2 : register(t2);

SamplerState s3_s : register(s3);

SamplerState s2_s : register(s2);

cbuffer cb2 : register(b2)
{
  float4 cb2[1];
}




//  declarations
#define cmp -


void main(
  float4 v0 : SV_POSITION0,
  float3 v1 : TEXCOORD0,
  out float4 o0 : SV_Target0)
{
  float4 r0,r1;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.x = t2.Sample(s2_s, v1.xy).x;
  r1.xyzw = t3.Sample(s3_s, v1.xy).xyzw;
  r0.xyzw = r1.xyzw * r0.xxxx;
  o0.xyzw = abs(cb2[0].xxxx * r0.xyzw);
  return;
}