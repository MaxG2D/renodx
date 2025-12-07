#include "./shared.h"
#include "./FakeHDRGain.h"

// Buildings with emissive windows shader

// --- Constants (Buffers) ---
float4 g_PS_windowStaticFresnel : register(c10);
float4 g_PS_viewDirWorld        : register(c16);
float4 g_PS_shadowMapMaxZ       : register(c19);
float4 g_PS_shadowMapScaleDepths[4] : register(c20); // c20 to c23
float4 g_PS_shadowMapOffsets[4]     : register(c24); // c24 to c27
float4 g_PS_skyDomeColor        : register(c34);
float4 g_PS_diffuseLightColor   : register(c37);
float4 g_PS_lightDirWorld       : register(c39);
float4 g_PS_specularLightColor  : register(c41);
float4 g_PS_fogColor            : register(c44);
float4 g_PS_windowEmitColor     : register(c51);

// --- Samplers ---
sampler2D   Tex0           : register(s0);  // Diffuse
samplerCUBE Tex1           : register(s1);  // Reflection Cube
sampler2D   NormalMap0     : register(s5);  // Normal Map
sampler2D   ShadowMapArray : register(s10); // Shadow Atlas

// --- ASM Constants ---
static const float4 c0 = float4(-0.5, 1, 0, 0.5);
static const float4 c1 = float4(-0, -1, -2, -3);
static const float4 c2 = float4(-0.899999976, -1.10000002, -2.0999999, -7.9999998e-005);
static const float4 c3 = float4(0.25, 0, 0, 0);
static const float4 c4 = float4(-0.000178710936, -0.000666992215, 0.000666992215, 0.000178710936);

struct PS_INPUT
{
    float2 TexCoord0 : TEXCOORD0;
    float3 ViewVec   : TEXCOORD1; // v1
    float3 LightPos  : TEXCOORD2; // v2
    float3 Tangent   : TEXCOORD3; // v3
    float3 Binormal  : TEXCOORD4; // v4
    float3 Normal    : TEXCOORD5; // v5
    float4 Color     : TEXCOORD6; // v6
    float  Fog       : TEXCOORD7; // v7
    float3 ReflVec   : TEXCOORD8; // v8
};

float4 main(PS_INPUT IN) : COLOR
{
    float4 r0, r1, r2, r3, r4, r5, r6, r7;
    
    r0 = tex2D(Tex0, IN.TexCoord0);
    r1 = texCUBE(Tex1, IN.ReflVec);
    
    // 0: Specular Mask (r1.w = saturate(r0.w * 2))
    r1.w = saturate(r0.w + r0.w);
    
    // 1: Load Normal Map (DXT5nm / BC3 typically puts X in Alpha, Y in Green)
    r2 = tex2D(NormalMap0, IN.TexCoord0);
    
    // Unpack Normal:
    // ASM: add r2.xy, r2.wyzw, c0.x  (Moves W->X, Y->Y, subtracts 0.5)
    // ASM: add r2.xy, r2, r2         (Multiplies by 2)
    float nx = r2.w * 2.0 - 1.0;
    float ny = r2.y * 2.0 - 1.0;
    
    // Reconstruct Z:
    // ASM: mad r2.z, -x*x + 1 ...
    // Safe reconstruction: sqrt(1 - x^2 - y^2)
    float nz_sq = 1.0 - (nx * nx + ny * ny);
    float nz = sqrt(max(nz_sq, 0.0)); 
    
    // Transform Normal to World Space (TBN)
    // ASM: mul r3, ny, Binormal
    // ASM: mad r2, nx, Tangent, r3
    // ASM: mad r2, nz, Normal, r2
    float3 worldNormal = (nx * IN.Tangent) + (ny * IN.Binormal) + (nz * IN.Normal);
    r3.xyz = normalize(worldNormal);
    
    // 13: Lighting Dot Product (N dot L)
    r2.x = saturate(dot(r3.xyz, g_PS_lightDirWorld.xyz));
    
    // 14: Shadow Cascade Logic
    r2.y = dot(IN.ViewVec, g_PS_viewDirWorld.xyz);
    r2.z = -r2.y - g_PS_shadowMapMaxZ.w;
    
    // Select cascade based on depth
    // (Mimicking ASM cmp/logic for cascade selection)
    float cascadeMask = (r2.z >= 0.0) ? c0.z : c0.y; // 0 or 1
    float litMask     = (-r2.x >= 0.0) ? c0.z : c0.y; // 0 or 1
    r2.z = cascadeMask * litMask;
    
    if (r2.z != -r2.z) // if (Lit and within range)
    {
        // Calculate Cascade Index
        float3 distVec = (-r2.y) - g_PS_shadowMapMaxZ.xyz;
        
        // ASM: cmp r4.xyz, r4, c0.y, c0.z (1.0 if >= 0, else 0.0)
        float3 distMask = (distVec >= 0.0) ? float3(1,1,1) : float3(0,0,0);
        float cascadeIndex = dot(distMask, float3(1,1,1)); // 0, 1, 2, or 3

        // Select Scale/Offset (ASM Lines 27-34)
        // ASM logic uses abs comparisons on (Index - 0, Index - 1...).
        // We can just use the calculated index to fetch the array directly.
        int idx = (int)cascadeIndex; 
        if(idx > 3) idx = 3;

        float4 vScale  = g_PS_shadowMapScaleDepths[idx];
        float4 vOffset = g_PS_shadowMapOffsets[idx];

        // --- Shadow Coordinates (ASM Lines 35-46) ---
        // This is where the specific Atlas logic happens
        
        float2 baseUV = IN.LightPos.xy * vScale.xy + vOffset.xy;
        float3 r5_cond = cascadeIndex + c2.xyz;
        float2 uv_half = baseUV * 0.5;
        // c0.wzzw is (0.5, 0, 0, 0.5)
        float4 R6_reg = float4(baseUV * 0.5, baseUV * 0.5) + float4(0.5, 0.0, 0.0, 0.5);
        float2 R2_zw = baseUV * 0.5 + 0.5;

        // CMP Chain
        // These select which UV set to use based on r5_cond (Cascade level)
        
        // R4 currently holds (baseUV.x, baseUV.y, uv_half.x, uv_half.y)
        float4 R4_reg = float4(baseUV, uv_half);
        float4 R2_reg = float4(r2.x, r2.y, R2_zw); // x,y preserved, zw updated
        
        // Line 40: cmp r2.zw, r5.z, r2, r6
        float2 tmp_R2_zw = (r5_cond.z >= 0.0) ? R2_reg.zw : R6_reg.xy; // .xy of R6 matches ASM mapping

        // Line 41: cmp r2.zw, r5.y, r2, r6.xyxy
        // Note: ASM uses "r2" which now holds the result of Line 40
        tmp_R2_zw = (r5_cond.y >= 0.0) ? tmp_R2_zw : R6_reg.xy; // Wait, R6 in ASM line 41 is swizzled? 
        // ASM: cmp r2.zw, r5.y, r2, r6.xyxy -> Actually R6 is float4.
        // mad r6, r4.xyxy, c0.w, c0.wzzw 
        // R6.x = UV.x * 0.5 + 0.5
        // R6.y = UV.y * 0.5 + 0.0
        // R6.z = UV.x * 0.5 + 0.0
        // R6.w = UV.y * 0.5 + 0.5
        // R6 contains the 4 quadrant offsets.
        
        // Default (Cascade 0/1 usually):
        float2 uv_base = baseUV;
        
        // If Cascade is high (2 or 3), coordinates are scaled and offset
        // The CMP chain implies:
        // If (Index >= 3) -> Use Scaled/Offset UVs (Quadrant logic)
        // If (Index >= 2) -> Use Scaled/Offset UVs
        // If (Index >= 1) -> Use Base UVs
        
        // STRICT ASM EMULATION FOR COORDINATES:
        float4 coord_A = float4(R2_zw, R2_zw);
        
        // Line 40: cmp r2.zw, r5.z, r2, r6
        // If Index >= 2.1 (Cascade 3): Pick R2(Line39) else R6(Line38)
        // R2(Line39).zw = UV*0.5 + 0.5
        // R6(Line38)    = Vector of 4 quadrant combos
        float2 res_40 = (r5_cond.z >= 0.0) ? R2_zw : R6_reg.zw; // ASM uses r6 (zw part effectively for logic flow, but let's trust the registers)
        
        float2 val_true, val_false;
        
        // 40: cmp r2.zw, r5.z, r2, r6
        // r2 inputs are R2_zw. r6 inputs are R6.zw (implicit mapping for zw write)
        val_true  = R2_zw; 
        val_false = R6_reg.zw; // z,w of R6
        float2 res_zw = (r5_cond.z >= 0.0) ? val_true : val_false;
        
        // 41: cmp r2.zw, r5.y, r2, r6.xyxy
        val_true  = res_zw;
        val_false = R6_reg.xy;
        res_zw = (r5_cond.y >= 0.0) ? val_true : val_false;
        
        // 42: cmp r2.zw, r5.x, r2, r4
        // r4 input here is r4.zw (uv_half)
        val_true  = res_zw;
        val_false = uv_half; // R4.zw
        res_zw = (r5_cond.x >= 0.0) ? val_true : val_false;
        
        // Now we have the base coordinate "res_zw".
        // ASM Lines 43-46 apply offsets c4 to this base.
        // 43: add r4.xy, r2.zwzw, c4
        float2 uv0 = res_zw + c4.xy;
        // 44: add r5.xy, r2.zwzw, c4.zxzw
        float2 uv1 = res_zw + float2(c4.z, c4.x);
        // 45: add r6.xy, r2.zwzw, c4.ywzw
        float2 uv2 = res_zw + float2(c4.y, c4.w);
        // 46: add r7.xy, r2.zwzw, c4.wzzw
        float2 uv3 = res_zw + float2(c4.w, c4.z);
        
        // --- Sampling (ASM Lines 47-51) ---
        // Important: Z must be 0 for texture atlas lookup
        float4 s0 = tex2Dlod(ShadowMapArray, float4(uv0, 0, 0));
        float4 s1 = tex2Dlod(ShadowMapArray, float4(uv1, 0, 0));
        float4 s2 = tex2Dlod(ShadowMapArray, float4(uv2, 0, 0));
        float4 s3 = tex2Dlod(ShadowMapArray, float4(uv3, 0, 0));
        
        // --- Shadow Comparison (ASM Lines 51-60) ---
        // 51: add r2.z, c2.w, v2.z (Depth comparison)
        float depthRef = c2.w + IN.LightPos.z;
        
        // Gather X components (Red channel holds depth)
        float4 moments = float4(s0.x, s1.x, s2.x, s3.x);
        
        // 55: add r4, -r2.z, r4 (Shadow - Depth)
        float4 diff = moments - depthRef;
        
        // 56: cmp r4, r4, c0.y, c0.z (1 if >= 0, else 0)
        float4 shadowTest = (diff >= 0.0) ? 1.0 : 0.0;
        
        // 57: dp4 r2.z, r4, c3.x (Sum * 0.25)
        float shadowVal = dot(shadowTest, 0.25);
        
        // 58-60: Distance Fade
        float fade = saturate(-r2.y * (1.0 / g_PS_shadowMapMaxZ.w));
        r3.w = lerp(shadowVal, IN.Color.w, fade);
    }
    else
    {
        // 61: Else (No shadow calculation)
        r3.w = IN.Color.w;
    }
    
    // 64: Apply Lighting to Diffuse
    float3 diffuseLight = r2.x * g_PS_diffuseLightColor.xyz;
    diffuseLight = diffuseLight * r3.w + IN.Color.rgb;
    diffuseLight = max(diffuseLight, 0.0);
    
    float3 finalDiffuse = r0.rgb * diffuseLight;
    
    // 70: Fresnel Calculation
    float3 viewDir = normalize(IN.ViewVec);
    float fresnelTerm = 1.0 - abs(dot(viewDir, r3.xyz)); // r3 is WorldNormal
    fresnelTerm = max(fresnelTerm, 0.0);
    fresnelTerm = pow(fresnelTerm, g_PS_windowStaticFresnel.z);
    
    // LRP_PP r2.w (Fresnel Lerp)
    float fresnel = lerp(g_PS_windowStaticFresnel.x, g_PS_windowStaticFresnel.y, fresnelTerm);
    float specMask = r1.w * fresnel; // r1.w was texture alpha * 2
    
    // 77: Reflection / Sky Mixing
    // ASM: mad r1.xyz, r1, c34.w, -finalDiffuse
    // ASM: mad r1.xyz, specMask, r1, finalDiffuse
    // Formula: lerp(finalDiffuse, Reflection * SkyAlpha, specMask)
    float3 reflection = r1.rgb * g_PS_skyDomeColor.w;
    float3 combinedColor = lerp(finalDiffuse, reflection, specMask);
    
    // 82: Specular Highlight
    float3 reflVec = normalize(IN.ReflVec);
    float specDot = dot(reflVec, g_PS_lightDirWorld.xyz);
    float specP = pow(max(specDot, 0.0), g_PS_windowStaticFresnel.w);
    float specular = specMask * specP; // ASM multiplies with Fresnel result (r3.x)
    
    // Shadow mask on specular (ASM line 87: cmp r2.x, -r3.w, ...)
    if (r3.w <= 0.001) specular = 0.0;
    
    combinedColor += specular * g_PS_specularLightColor.rgb;
    
    // 89: Window Emissive Logic
    // r0.w is Diffuse Alpha
    float emitAlpha = saturate((r0.w + c0.x) * 2.0); // (a - 0.5) * 2
    float invFresnel = c0.y - fresnel; // 1.0 - Fresnel
    
    emitAlpha = emitAlpha * invFresnel;

    float3 emissive = r0.rgb * g_PS_windowEmitColor.rgb;
    //emissive = ApplyFakeHDRGain(emissive, pow(1.5, 15), pow(1.5, 15), 1.5);
    float3 finalColor = emitAlpha * emissive + combinedColor;
    float finalAlpha = saturate(r1.w * fresnel + specular);
    float3 foggedColor = lerp(finalColor, g_PS_fogColor.rgb, IN.Fog);
    
    return float4(foggedColor, finalAlpha);
}