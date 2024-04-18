// Thu Apr 18 21:35:00 2024
Texture2D<float4> t0 : register(t0);

SamplerState s0_s : register(s0);




//  declarations
#define cmp -


void main(
  float4 v0 : SV_POSITION0,
  float3 v1 : TEXCOORD0,
  out float4 o0 : SV_Target0)
{
  float4 r0,r1,r2,r3;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyzw = t0.Sample(s0_s, v1.xy).xyzw;
  r1.xy = v1.xy;
  r2.xyzw = float4(0,0,0,0);
  r1.z = -2;

  o0.xyz = r2.xyz + r0.xyz;
  r0.x = r2.w + r0.w;
  o0.w = v1.z * r0.x;
  return;
}