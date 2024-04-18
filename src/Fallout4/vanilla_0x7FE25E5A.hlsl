// Sun Apr 14 14:07:01 2024
Texture2D<float4> t0 : register(t0);

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
  float4 v2 : COLOR0,
  float4 v3 : POSITION0,
  float4 v4 : POSITION1,
  out float4 o0 : SV_Target0,
  out float4 o1 : SV_Target1)
{
  float4 r0,r1;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyzw = t0.Sample(s0_s, v1.xy).xyzw;
  r0.w = log2(r0.w);
  r0.xyz = v2.xyz * r0.xyz;
  r0.w = 2.20000005 * r0.w;
  r0.w = exp2(r0.w);
  o0.w = v2.w * r0.w;
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