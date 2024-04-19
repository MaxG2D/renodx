// Thu Apr 18 21:40:51 2024
Texture2D<float4> t6 : register(t6);

Texture2D<float4> t0 : register(t0);

SamplerState s6_s : register(s6);

SamplerState s0_s : register(s0);

cbuffer cb2 : register(b2)
{
  float4 cb2[15];
}

cbuffer cb1 : register(b1)
{
  float4 cb1[3];
}

cbuffer cb0 : register(b0)
{
  float4 cb0[2];
}




//  declarations
#define cmp -


void main(
  float4 v0 : SV_POSITION0,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD4,
  float4 v3 : COLOR1,
  float3 v4 : TEXCOORD1,
  out float4 o0 : SV_Target0)
{
  float4 r0,r1,r2;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyzw = t0.Sample(s0_s, v1.xy).xyzw;
  r1.xyzw = cb1[0].xyzw * r0.xyzw;
  r0.xyz = cb2[13].xyz * r1.xyz + -r1.xyz;
  r0.xyz = cb1[2].xxx * r0.xyz + r1.xyz;
  r1.xyz = v3.xyz + -r0.xyz;
  r0.xyz = v3.www * r1.xyz + r0.xyz;
  r1.x = cb2[13].w * r1.w + -cb2[14].x;
  r1.x = cmp(r1.x < 0);
  if (r1.x != 0) discard;
  r1.x = cmp(cb0[1].y == 0.000000);
    if (r1.x != 0) {
    r1.xyzw = t6.Sample(s6_s, v1.xy).xyzw;
  } else {
    r1.xyzw = t6.Sample(s6_s, v1.xy).xyzw;
  }
  r1.xyz = r1.xyz * cb0[1].www + r0.xyz;
  r0.x = cmp(cb0[1].x != 0.000000);
  r2.xyzw = cb1[0].wwww * r1.xyzw;
  r1.xyzw = r0.xxxx ? r2.xyzw : r1.xyzw;
  r0.x = cb0[1].z * r1.w;
  r0.y = cmp(cb2[14].y < 1);
  if (r0.y != 0) {
    r0.y = cb2[14].y + -r0.w;
    r0.y = cmp(r0.y < 0);
    if (r0.y != 0) discard;
  }
  o0.xyz = r1.xyz * r0.xxx;
  o0.w = r0.x;
  return;
}