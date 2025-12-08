#include "./shared.h"
#include "./FakeHDRGain.h"

// Car headlights shader

// --- Constants ---
const static float4 C2 = float4(-0.5, 1.0, -0.996078432, -0.501960814);
const static float4 C3 = float4(0.800000012, 0.100000001, 2.02380943, 2.00787401);
const static float4 C4 = float4(-0.0390000008, 0.0, 1.0, 0.5);
const static float4 C5 = float4(0.0, -1.0, -2.0, -3.0);
const static float4 C6 = float4(-0.899999976, -1.10000002, -2.0999999, -7.9999998e-005);
const static float4 C7 = float4(0.25, 0.0, 0.0, 0.0);
const static float4 C8 = float4(-0.000178710936, -0.000666992215, 0.000666992215, 0.000178710936);

// --- Registers ---
float4 g_PS_visibilityFactors : register(c0);
float4 g_PS_externalLight : register(c1);
float4 g_PS_viewDirWorld : register(c16);
float4 g_PS_shadowMapMaxZ : register(c19);
float4 g_PS_shadowMapScaleDepths[4] : register(c20);
float4 g_PS_shadowMapOffsets[4] : register(c24);
float4 g_PS_ambientBlack : register(c32);
float4 g_PS_diffuseLightColor : register(c37);
float4 g_PS_lightDirWorld : register(c39);
float4 g_PS_specularLightColor : register(c41);
float4 g_PS_fogColor : register(c44);
float4 g_PS_textureGlowParams : register(c48);
float g_PS_carReflectionIntensity : register(c58);
float4 g_PS_carLightReflectorSpecular : register(c124);
float4 g_PS_carLightGlassSpecular : register(c125);
float4 g_PS_carLightPlasticSpecular : register(c126);

// --- Samplers ---
sampler2D Tex0 : register(s0);
samplerCUBE Tex1 : register(s1);
sampler2D Tex2 : register(s2);
sampler2D NormalMap0 : register(s5);
sampler2D ShadowMapArray : register(s10);

struct PSInput
{
  float2 TexCoord0 : TEXCOORD0;
  float3 NormalWS : TEXCOORD1;
  float3 LightSpaceUVZ : TEXCOORD2;
  float4 Color : COLOR0;
  float3 TangentWS : TEXCOORD3;
  float3 BinormalWS : TEXCOORD4;
  float3 ViewDirTS : TEXCOORD5;
};

float4 main(PSInput input) : COLOR
{
  float4 r0 = 0, r1 = 0, r2 = 0, r3 = 0, r4 = 0, r5 = 0, r6 = 0, r7 = 0, r8 = 0, r9 = 0, r10 = 0;
  float4 oC0;

  // --- Normal Decode & Reflection Vector ---
  r0.xyz = normalize(input.NormalWS.xyz);
  r1 = tex2D(NormalMap0, input.TexCoord0);
 
  r1.x = r1.w + C2.x; r1.y = r1.y + C2.x; r1.xy = r1.xy + r1.xy;
  r0.w = (r1.x * -r1.x) + C2.y; r0.w = (r1.y * -r1.y) + r0.w;
  r0.w = rsqrt(r0.w); r0.w = 1.0 / r0.w;

  r1.yzw = r1.y * input.BinormalWS.xyz;
  r1.xyz = mad(r1.x, input.TangentWS.xyz, r1.yzw);
  r1.xyz = mad(r0.w, input.ViewDirTS.xyz, r1.xyz);
  r2.xyz = normalize(r1.xyz);

  r0.w = dot(-r0.xyz, r2.xyz);
  r0.w = r0.w + r0.w;
  r1.xyz = mad(r2.xyz, -r0.w, -r0.xyz);

  // --- Textures & Specular Setup ---
  r3 = tex2D(Tex0, input.TexCoord0);
  r4 = texCUBE(Tex1, r1.xyz);
  r5 = tex2D(Tex2, input.TexCoord0);
  r6.xyz = r3.xyz * r5.w;
 
  r7.xy = r3.w + C2.zw;
  r8.xy = g_PS_carLightGlassSpecular.xy;

  r7.zw = (r7.y >= 0.0) ? r8.yx : g_PS_carLightPlasticSpecular.yx;
  r6.xyz = (r7.x >= 0.0) ? r6.xyz : r5.w;
  r7.zw = (r7.x >= 0.0) ? g_PS_carLightReflectorSpecular.yx : r7.zw;

  // --- Specular Fresnel Power/Factor ---
  r0.w = saturate(dot(r1.xyz, g_PS_lightDirWorld.xyz));
  r0.x = dot(r0.xyz, r2.xyz);              
  r0.y = C2.y - abs(r0.x);               
 
  r0.z = r0.y * r0.y;                  
  r0.z = r0.z * r0.z;                  
  r0.y = r0.y * r0.z;                  
 
  r1.x = mad(r0.y, C3.x, C3.y);             
  r1.y = r7.y * C3.z; // Specular Power Factor
  r1.z = r3.w * C3.w;                  
 
  r0.y = r1.x; // ASM Line 33: Store Fresnel factor into r0.y for Specular Accumulation
 
  r0.yz = (r7.y >= 0.0) ? r1.xx : r1.yz;        
  r1.xy = (r7.x >= 0.0) ? C2.y : r0.yz;         

  // --- Texkill ---
  r8.x = r1.y + C4.x;
  clip(r8.x);

  // --- Shadowing Setup & Calculation (Lines 37-87) ---
  r0.z = saturate(dot(r2.xyz, g_PS_lightDirWorld.xyz));

  // Front-facing check (r1.z) combined with max-depth check (r2.x)
  r1.z = (-r0.z >= 0.0) ? C4.y : C4.z;
  r1.w = dot(input.NormalWS.xyz, g_PS_viewDirWorld.xyz);

  r2.x = (-r1.w) - g_PS_shadowMapMaxZ.w;
  r2.x = (r2.x >= 0.0) ? C4.z : C4.y;
  r2.x = r1.z * r2.x;

  if (r2.x != 0.0)
  {
    r2.xyz = (-r1.w) - g_PS_shadowMapMaxZ.xyz;
    r2.xyz = (r2.xyz >= 0.0) ? C4.z : C4.y;

    r2.x = dot(C2.y, r2.xyz);
    r8 = r2.x + C5;
    r2.y = C4.y;

    r2.zw = (abs(r8.x) >= 0.0) ? g_PS_shadowMapScaleDepths[0].xy : r2.y;
    r2.zw = (abs(r8.y) >= 0.0) ? g_PS_shadowMapScaleDepths[1].xy : r2.zw;
    r2.zw = (abs(r8.z) >= 0.0) ? g_PS_shadowMapScaleDepths[2].xy : r2.zw;
    r2.zw = (abs(r8.w) >= 0.0) ? g_PS_shadowMapScaleDepths[3].xy : r2.zw;

    r9.xy = (abs(r8.x) >= 0.0) ? g_PS_shadowMapOffsets[0].xy : r2.y;
    r8.xy = (abs(r8.y) >= 0.0) ? g_PS_shadowMapOffsets[1].xy : r9.xy;
    r8.xy = (abs(r8.z) >= 0.0) ? g_PS_shadowMapOffsets[2].xy : r8.xy;
    r8.xy = (abs(r8.w) >= 0.0) ? g_PS_shadowMapOffsets[3].xy : r8.xy;

    r2.yz = mad(input.LightSpaceUVZ.xy, r2.xz, r8.xy);
    r8.xy = r2.yz * (-C2.x);
    r9.xyz = r2.x + C6.xyz;

    r10 = mad(r2.yzyz, C4.w, C4.w);
    r2.xy = mad(r2.yz, -C2.x, C2.x);

    r2.xy = (r9.z >= 0.0) ? r2.xy : r10.zw;
    r2.xy = (r9.y >= 0.0) ? r2.xy : r10.xy;
    r2.xy = (r9.x >= 0.0) ? r2.xy : r8.xy;

    r8.xy = r2.xy + C8.xy; r9.xy = r2.xy + C8.zx;
    r10.xy = r2.xy + C8.yw; r2.xy = r2.xy + C8.wz;

    r8.z = r2.x; r8.w = C4.y; r8 = tex2Dlod(ShadowMapArray, r8);
    r9.z = r2.x; r9.w = C4.y; r9 = tex2Dlod(ShadowMapArray, r9);
    r10.z = r2.x; r10.w = C4.y; r10 = tex2Dlod(ShadowMapArray, r10);
    r2.z = r2.x; r2.w = C4.y; r2 = tex2Dlod(ShadowMapArray, r2);

    r2.y = C6.w + input.LightSpaceUVZ.z;
    r8.y = r9.x; r8.z = r10.x; r8.w = r2.x;
    r2 = r8 - r2.y;

    r2 = (r2 >= 0.0) ? C4.z : C4.y;
    r2.x = dot(r2, C7.x);
    r2.y = 1.0 / g_PS_shadowMapMaxZ.w;
    r1.w = saturate(-r1.w * r2.y);
    r3.w = lerp(g_PS_visibilityFactors.x, r2.x, r1.w);
  }
  else { r3.w = g_PS_visibilityFactors.x; }
 
  // --- ACCUMULATION & DIFFUSE LIGHTING (Lines 88-92) ---
  r2.xyz = g_PS_ambientBlack.xyz + input.Color.xyz;
  r1.w = r0.z * r3.w; // r0.z is front-facing * shadow factor
  r2.xyz = mad(r1.w, g_PS_diffuseLightColor.xyz, r2.xyz);
  r2.xyz = mad(r0.z, g_PS_externalLight.xyz, r2.xyz);
  r2.xyz = r3.xyz * r2.xyz;

  // Save Diffuse/Ambient component before r2 is overwritten
  r9.xyz = r2.xyz;

  // --- Specular & Reflection Phase (Lines 93-118) ---

  // 93: Specular Masking: Front-facing check (r1.z) * Shadow Factor (r3.w)
  r0.z = r1.z * r3.w;

  // 94-96: Base Specular Calculation
  r3.xyz = r0.z * g_PS_specularLightColor.xyz;
  r3.xyz = r7.w * r3.xyz;
  r3.xyz = r6.xyz * r3.xyz;

  // 97-100: Specular Power/Finalize
  r1.z = pow(abs(r0.w), r7.z);
  r1.z = saturate(r1.z);
  r3.xyz = r3.xyz * r1.z;

  // 101-102: Reflection Component
  r6.xyz = r6.xyz * g_PS_carReflectionIntensity;
  r4.xyz = r4.xyz * r6.xyz;

  // 103-109: Blend Factors & Component Generation
  r0.z = (-r5.w) + C2.y; // 103: (1.0 - r5.w)
  r6.xyz = r9.xyz * r0.z; // 104: Diffuse/Ambient * (1.0 - Texture Alpha)
  r8.xyz = r1.x * r4.xyz; // 105: Reflection * Fresnel factor (r1.x)

  r0.z = C2.y - r1.x; // 106.z: (1.0 - Fresnel)
  r0.w = C2.y - r1.y; // 106.w: (1.0 - Specular Power Factor)

  r1.x = r1.y * r0.z; // 107: Specular Power Factor * (1.0 - Fresnel)
  r1.xyz = r9.xyz * r1.x; // 108: Diffuse/Ambient * Blend factor (r1.x)
  r8.w = mad(r0.z, -r0.w, C2.y); // 109: (1.0 - Fresnel) * (r1.y - 1.0) + 1.0

  // 110: Choose between r6 (full diffuse/ambient) and r1 (blended diffuse/ambient)
  r1.xyz = (r7.x >= 0.0) ? r6.xyz : r1.xyz;
  float3 r3_spec = float3(r0.y * r3.x, r0.y * r3.x, r0.y * r3.y);
  r0.yzw = (r7.x >= 0.0) ? r3_spec : r3.xyz;

  r4.w = C2.y;
  r2 = (r7.x >= 0.0) ? r4 : r8; // 114: Choose final reflection/alpha component (r2.xyz = r4 or r8)
  r1.w = C2.y + (-input.Color.w);
  oC0.w = r2.w * r1.w;

  // 117: Add Diffuse/Ambient Blend (r1.xyz) + Final Specular (r0.yzw)
  r0.y = r1.x + r0.y;
  r0.z = r1.y + r0.z;
  r0.w = r1.z + r0.w;

  // 118: Add Reflection (r2.xyz) + Result
  r0.y = r2.x + r0.y;
  r0.z = r2.y + r0.z;
  r0.w = r2.z + r0.w;

  // --- Fog & Glow ---
  r1.xyz = lerp(float3(r0.y, r0.z, r0.w), g_PS_fogColor.xyz, input.Color.w);

  // r0.x (unmasked dot product)
  r2.x = max(r0.x, C4.y);
  r0.x = r2.x * g_PS_textureGlowParams.z;
  // The logs must use the raw texture values r5.xyz
  r0.y = log(r5.x); r0.z = log(r5.y); r0.w = log(r5.z);
  r0.yzw = r0.yzw * g_PS_textureGlowParams.w;
  r2.x = exp(r0.y); r2.y = exp(r0.z); r2.z = exp(r0.w);
  if (RENODX_TONE_MAP_TYPE > 0)
  {
    r2.xyz = ApplyFakeHDRGain(r2.xyz, pow(Custom_Headlights_Glow, 15), pow(Custom_Headlights_Glow_Contrast, 15), Custom_Headlights_Glow_Saturation);
  }
  r0.xyz = r0.x * r2.xyz;

  oC0.xyz = mad(r1.w, r0.xyz, r1.xyz);

  return max(oC0, 0.f);
}