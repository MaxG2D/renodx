#include "./shared.h"

Texture2D<float4> t11 : register(t11);

Texture2D<float4> t10 : register(t10);

Texture2D<float4> t9 : register(t9);

Texture2D<float4> t7 : register(t7);

Texture2D<float4> t6 : register(t6);

Texture2D<float4> t5 : register(t5);

Texture2D<float4> t4 : register(t4);

Texture2D<float4> t1 : register(t1);

SamplerState s10_s : register(s10);

SamplerState s9_s : register(s9);

SamplerState s7_s : register(s7);

SamplerState s6_s : register(s6);

SamplerState s5_s : register(s5);

SamplerState s4_s : register(s4);

SamplerState s1_s : register(s1);

cbuffer cb2 : register(b2)
{
  float4 cb2[5];
}

cbuffer cb1 : register(b1)
{
  float4 cb1[14];
}

cbuffer cb0 : register(b0)
{
  float4 cb0[7];
}

cbuffer cb12 : register(b12)
{
  float4 cb12[47];
}




//  declarations
#define cmp -


void main(
  float4 v0 : SV_POSITION0,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD4,
  float4 v3 : TEXCOORD1,
  float4 v4 : TEXCOORD2,
  float3 v5 : TEXCOORD5,
  out float4 o0 : SV_Target0)
{
  float4 r0,r1,r2,r3,r4,r5,r6,r7,r8,r9;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.x = dot(v1.xyz, v1.xyz);
  r0.x = rsqrt(r0.x);
  r0.xyz = v1.xyz * r0.xxx;
  r0.w = -8192 + v1.w;
  r1.x = -8192 + cb1[10].x * 1; 						                                    //Something with waves?
  r0.w = saturate(r0.w / r1.x);
  r1.xy = cb0[0].xy * v0.xy;
  r1.z = t7.Sample(s7_s, r1.xy).x;
  r1.w = cmp(0.00999999978 >= r1.z);
  if (r1.w != 0) {
    r2.z = 100 * r1.z;
    r3.xyzw = cb12[24].xyzw;
    r4.xyzw = cb12[25].xyzw;
    r5.xyzw = cb12[26].xyzw;
    r6.xyzw = cb12[27].xyzw;
  } else {
    r2.z = r1.z * 1.00999999 + -0.00999999978;
    r3.xyzw = cb12[20].xyzw;
    r4.xyzw = cb12[21].xyzw;
    r5.xyzw = cb12[22].xyzw;
    r6.xyzw = cb12[23].xyzw;
  }
  r7.x = cb0[0].z * r1.x;
  r7.z = -r1.y * cb0[0].w + 1;
  r2.xy = r7.xz * float2(2,2) + float2(-1,-1);
  r2.w = 1;
  r3.x = dot(r3.xyzw, r2.xyzw);
  r3.y = dot(r4.xyzw, r2.xyzw);
  r3.z = dot(r5.xyzw, r2.xyzw);
  r1.z = dot(r6.xyzw, r2.xyzw);
  r2.xyz = r3.xyz / r1.zzz;
  r1.z = dot(r2.xyz, r2.xyz);
  r1.z = sqrt(r1.z);
  r2.xyz = r1.zzz * -r0.xyz;
  r1.z = dot(r2.xyz, cb2[4].xyz);
  r1.w = dot(r2.xyz, r2.xyz);
  r1.w = sqrt(r1.w);
  r2.x = cb2[4].w / r1.z;
  r2.x = 1 + -r2.x;
  r1.w = r2.x * r1.w;
  r1.w = r1.w / cb1[10].w;
  r1.z = r2.x * abs(r1.z);
  r1.z = r1.z / cb1[10].w;
  r1.zw = saturate(float2(1,1) + -r1.zw);
  r2.xy = cb1[12].xw + -cb1[12].yz;
  r1.w = -cb1[12].y + r1.w;
  r2.x = 1 / r2.x;
  r1.w = saturate(r2.x * r1.w);
  r2.x = r1.w * -2 + 3;
  r1.w = r1.w * r1.w;
  r1.w = -r2.x * r1.w + 1;
  r1.w = log2(r1.w);
  r1.w = 0.330000013 * r1.w;
  r1.w = exp2(r1.w);
  r1.w = r1.w * r2.y + cb1[12].z;
  r2.x = 1 + -cb1[11].x;
  r2.yz = -cb1[11].xw + r1.zz;
  r1.z = 1 / r2.x;
  r1.z = saturate(r2.y * r1.z);
  r2.x = r1.z * -2 + 3;
  r1.z = r1.z * r1.z;
  r1.z = r2.x * r1.z;
  r2.x = cb1[11].z + -cb1[11].w;
  r2.x = 1 / r2.x;
  r2.x = saturate(r2.z * r2.x);
  r2.y = r2.x * -2 + 3;
  r2.x = r2.x * r2.x;
  r2.x = (-r2.y * r2.x  + 1) * 1; 						                                  //Specular dots amount
  r2.x = cb1[11].y * r2.x;
  r2.yz = t4.Sample(s4_s, v3.xy).xy;
  r3.xy = r2.yz + r2.yz * 1; 							                                      //Water roughness, best to keep at 1 to not destroy blending with cheap water
  r2.yz = r2.yz * float2(2,2) + float2(-1,-1);
  r2.y = dot(r2.yz, r2.yz);
  r2.y = min(1, r2.y);
  r2.y = 1 + -r2.y;
  r3.z = sqrt(r2.y);
  r2.yzw = float3(-1,-1,-1) + r3.xyz;
  r2.yzw = cb1[9].xxx * r2.yzw + float3(0,0,1);
  r3.xy = t5.Sample(s5_s, v3.zw).xy;
  r3.xy = r3.xy * float2(2,2) + float2(-1,-1);
  r3.w = dot(r3.xy, r3.xy);
  r3.w = min(1, r3.w);
  r3.w = 1 + -r3.w;
  r3.z = sqrt(r3.w * injectedData.fxWaterSpecularRoughness);         						//Specular roughness 2
  r4.xy = t6.Sample(s6_s, v4.xy).xy;
  r4.xy = r4.xy * float2(2,2) + float2(-1,-1);
  r3.w = dot(r4.xy, r4.xy);
  r3.w = min(1, r3.w);
  r3.w = 1 + -r3.w;
  r4.z = sqrt(r3.w * injectedData.fxWaterSpecularRoughness);								    //Specular roughness 2
  r3.xyz = cb1[9].yyy * r3.xyz * injectedData.fxWaterWavesHeight;				        //Waves Height
  r4.xyz = cb1[9].zzz * r4.xyz * injectedData.fxWaterWavesScale;					      //Waves UV scale
  r2.yzw = r3.xyz * r0.www + r2.yzw;
  r2.yzw = r4.xyz * r0.www + r2.yzw;
  r3.x = dot(r2.yzw, r2.yzw);
  r3.x = rsqrt(r3.x);
  r2.yzw = r2.yzw * r3.xxx + float3(-0,-0,-1);
  r2.xyz = r2.xxx * r2.yzw + float3(0,0,1);
  r2.w = dot(r2.xyz, r2.xyz);
  r2.w = rsqrt(r2.w);
  r2.xyz = r2.xyz * r2.www;
  r3.x = saturate(dot(-r0.xyz, r2.xyz));
  r3.x = 1 + -r3.x;
  r3.y = 1 + -cb1[13].z;
  r3.z = r3.x * r3.x;
  r3.z = r3.z * r3.z;
  r3.x = r3.x * r3.z;
  r3.x = r3.y * r3.x + cb1[13].z;
  r0.x = dot(r0.xyz, r2.xyz);
  r0.x = r0.x + r0.x;
  r0.x = r2.z * -r0.x + r0.z;
  r0.y = saturate(0.75 + r0.x);
  r3.yzw = cb1[4].xyz + -cb1[3].xyz;
  r3.yzw = r0.yyy * r3.yzw + cb1[3].xyz;
  r0.x = saturate(r0.x * 1.89999998 + 0.349999994);
  r4.xyz = cb1[5].xyz + -r3.yzw;
  r0.xyz = r0.xxx * r4.xyz + r3.yzw;
  r4.xyzw = t9.SampleLevel(s9_s, r1.xy, 0).xyzw;
  r5.xyzw = t10.SampleLevel(s10_s, r1.xy, 0).xyzw;
  r5.xyzw = r5.xyzw + -r4.xyzw;
  r4.xyzw = cb0[6].xxxx * r5.xyzw + r4.xyzw;
  r3.yzw = r4.xyz + -r0.xyz;
  r0.xyz = r4.www * r3.yzw + r0.xyz;
  r3.yzw = -cb1[2].xyz + r0.xyz;
  r3.yzw = cb1[2].www * r3.yzw + cb1[2].xyz;
  t11.GetDimensions(0, fDest.x, fDest.y, fDest.z);
  r4.xy = fDest.xy;
  r4.z = 0.0625 * r2.z;
  r4.zw = r4.zz * r2.xy;
  r4.z = v0.x * cb0[0].x + -r4.z;
  r4.x = r4.z * r4.x;
  r5.x = (int)r4.x;
  r4.x = v0.y * cb0[0].y + r4.w;
  r4.x = r4.x * r4.y;
  r5.y = (int)r4.x;
  r4.xyz = t1.Sample(s1_s, r1.xy).xyz;
  r5.zw = float2(0,0);
  r6.xyz = t1.Load(r5.xyw).xyz;
  r1.x = t11.Load(r5.xyz).w;
  r1.xy = r1.xx * float2(255,255) + float2(-2,-3);
  r1.xy = cmp(abs(r1.xy) < float2(0.25,0.25));
  r1.x = (int)r1.y | (int)r1.x;
  r4.xyz = r1.xxx ? r6.xyz : r4.xyz;
  r5.xyz = -cb1[7].xyz + cb1[6].xyz;
  r5.xyz = r4.xyz * r5.xyz + cb1[7].xyz;
  r1.x = 1 + -r1.w;
  r5.xyz = r5.xyz + -r4.xyz;
  r1.xyw = r5.xyz * r1.xxx;
  r1.xyw = cb1[6].www * r1.xyw + r4.xyz;
  r4.xyz = v5.xyz;
  r4.w = 1;
  r4.x = dot(cb12[14].xyzw, r4.xyzw);
  r4.x = cb12[35].z + r4.x;
  r4.y = dot(v5.xyz, v5.xyz);
  r4.y = sqrt(r4.y);
  r4.y = r4.y * cb12[41].x + -cb12[41].z;
  r4.z = saturate(r4.y);
  r4.xw = saturate(r4.xx * cb12[46].xy + -cb12[46].zw);
  r4.w = r4.w + -r4.x;
  r4.x = r4.z * r4.w + r4.x;
  r4.w = cmp(0.75 < r4.y);
  r5.x = -0.75 + r4.z;
  r5.x = 4 * r5.x;
  r5.y = 1 + -cb12[43].w;
  r5.x = r5.x * r5.y + cb12[43].w;
  r5.x = min(1, r5.x);
  r4.w = r4.w ? r5.x : cb12[43].w;
  r4.y = cmp(r4.y < 0.0149999997);
  r5.x = 66.6666718 * r4.z;
  r4.y = r4.y ? r5.x : 1;
  r4.z = log2(r4.z);
  r4.z = cb12[42].w * r4.z;
  r4.z = exp2(r4.z);
  r4.z = min(r4.z, r4.w);
  r4.w = 1 + -r4.x;
  r4.w = r4.x * cb12[44].w + r4.w;
  r5.xyz = cb12[44].xyz + -cb12[42].xyz;
  r5.xyz = r4.zzz * r5.xyz + cb12[42].xyz;
  r7.xyz = cb12[45].xyz + -cb12[43].xyz;
  r7.xyz = r4.zzz * r7.xyz + cb12[43].xyz;
  r7.xyz = r7.xyz + -r5.xyz;
  r5.xyz = r4.xxx * r7.xyz + r5.xyz;
  r4.x = r4.z * r4.w;
  r4.x = r4.x * r4.y;
  r4.y = dot(-v5.xyz, -v5.xyz);
  r4.y = rsqrt(r4.y);
  r4.yzw = -v5.xyz * r4.yyy;
  r5.w = dot(-r4.yzw, cb0[1].xyz);
  r5.w = max(0, r5.w);
  r5.w = log2(r5.w);
  r5.w = cb0[2].w * r5.w;
  r5.w = exp2(r5.w);
  r5.w = cb0[1].w * r5.w;
  r7.xyz = cb0[2].xyz + -r5.xyz;
  r5.xyz = r5.www * r7.xyz + r5.xyz;
  r7.xyz = cb0[2].xyz * cb0[1].www * injectedData.fxWaterSpecularAmount; 				  //Water specular amount
  r5.w = saturate(dot(r2.xyz, float3(-0.0989999995,-0.0989999995,0.99000001)));
  r5.w = log2(r5.w);
  r5.w = cb1[0].w * r5.w;
  r5.w = exp2(r5.w);
  r8.xyz = r5.www * r7.xyz;
  r8.xyz = cb1[10].zzz * r8.xyz;
  r2.w = 1;
  r9.x = dot(cb12[0].xyzw, r2.xyzw);
  r9.y = dot(cb12[1].xyzw, r2.xyzw);
  r9.z = dot(cb12[2].xyzw, r2.xyzw);
  r2.x = dot(-r4.yzw, r9.xyz);
  r2.x = r2.x + r2.x;
  r2.xyz = r9.xyz * -r2.xxx + -r4.yzw;
  r2.x = saturate(dot(r2.xyz, cb0[1].xyz));
  r2.x = log2(r2.x);
  r2.x = cb1[8].x * r2.x;
  r2.x = exp2(r2.x);
  r2.xyz = r2.xxx * r7.xyz;
  r2.xyz = r2.xyz * cb1[1].www + r8.xyz;
  r2.w = cb1[8].y * r3.x;
  r0.xyz = -r1.xyw + r0.xyz;
  r0.xyz = r2.www * r0.xyz + r1.xyw;
  r0.xyz = r0.xyz + -r3.yzw;
  r0.xyz = r0.www * r0.xyz + r3.yzw;
  r0.xyz = r0.xyz + r2.xyz;
  r1.xyw = r6.xyz + -r0.xyz;
  r0.xyz = r1.zzz * r1.xyw + r0.xyz;
  r1.xyz = r5.xyz + -r0.xyz;
  o0.xyz = r4.xxx * r1.xyz + r0.xyz;
  o0.w = 0;
  return;
}