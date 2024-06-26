// Sat Apr 20 12:17:40 2024
Texture2D<float4> t1 : register(t1);

Texture2D<float4> t0 : register(t0);

SamplerState s1_s : register(s1);

SamplerState s0_s : register(s0);




//  declarations
#define cmp -


void main(
  float4 v0 : SV_POSITION0,
  float3 v1 : TEXCOORD0,
  out float4 o0 : SV_Target0)
{
  float4 r0,r1,r2;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyzw = t1.Sample(s1_s, v1.xy).xyzw;
  r0.w = saturate(0.899999976 * r0.w);
  r1.xyz = r0.xyz + r0.xyz;
  r1.w = 0.5 * r0.w;
  r0.xyzw = t0.Sample(s0_s, v1.xy).xyzw;
  r2.xyzw = r0.xyzw + -r1.xyzw;
  o0.xyzw = r0.wwww * r2.xyzw + r1.xyzw;
  return;
}