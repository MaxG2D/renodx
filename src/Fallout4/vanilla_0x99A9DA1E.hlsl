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
  r1.xy = float2(-0.000500000024,-0.00100000005) + v1.xy;
  r2.xyzw = float4(0,0,0,0);
  r1.z = -2;
  while (true) {
    r1.w = cmp(2 < (int)r1.z);
    if (r1.w != 0) break;
    r1.w = (int)r1.z;
    r3.xy = r1.ww * float2(9.99999975e-05,9.99999975e-05) + r1.xy;
    r3.xyzw = t0.Sample(s0_s, r3.xy).xyzw;
    r2.xyzw = r2.xyzw + r3.xyzw;
    r1.z = (int)r1.z + 1;
  }
  o0.xyz = r2.xyz * float3(0.0199999996,0.0199999996,0.0199999996) + r0.xyz;
  r0.x = saturate(r2.w * 2.5 + r0.w);
  o0.w = v1.z * r0.x;
  return;
}