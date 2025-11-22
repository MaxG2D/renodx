#include "./shared.h"

// Output shader
sampler2D TextureBase     : register(s0); // s0: Main Render
sampler2D TextureBloom    : register(s1); // s1: Bloom Buffer
sampler2D TextureGrading  : register(s2); // s2: 1D Color Grading LUT
sampler2D TextureVignette : register(s3); // s3: Vignette/Global Weight
sampler2D TextureBleach   : register(s4); // s4: Bleach Bypass Ramp
sampler2D TextureOverlay  : register(s5); // s5: Overlay/Dirt Layer

float4 g_BleachParams : register(c106); // x:Contrast, y:Mix, z:PreCurve, w:PostCurve
float4 g_CurveParams  : register(c109); // x:Gamma/Power, y:Scale
float4 g_BloomTint    : register(c110); // RGB Tint for Bloom
float4 g_Levels       : register(c112); // Levels Adjustment

struct PS_INPUT
{
    float2 uv : TEXCOORD0;
};

float4 main(PS_INPUT input) : COLOR
{
    // Constants
    const float3 LUMA_WEIGHTS = float3(0.2125f, 0.7154f, 0.0721f);
    const float  LUT_OFFSET   = 0.00048828125f;
    const float  LUT_V_COORD  = 0.03125f;
    const float  EPSILON      = 9.99999975e-005;

    // 1. Texture Composition
    // ----------------------
    float4 o            = float4(0, 0, 0, 1);
    float4 baseColor    = tex2D(TextureBase, input.uv);
    float4 overlayColor = tex2D(TextureOverlay, input.uv);
    float4 vignette     = tex2D(TextureVignette, float2(LUT_V_COORD, 0.0f));
    float4 bloomColor   = tex2D(TextureBloom, input.uv);

    // Combine Base and Overlay
    float3 composition = overlayColor.w * baseColor.rgb + overlayColor.rgb;

    // Apply Vignette/Global Weighting
    float3 combinedRGB;
    combinedRGB = composition * vignette.x;

    // 2. Color Grading (LUT Lookup)
    // -----------------------------
    // Transform RGB values to UV coordinates for the LUT
    float3 lutUV = combinedRGB * g_CurveParams.y + LUT_OFFSET;

    // Sample LUT, but for now only for "vanilla" tonemapping option, because LUT clamps to SDR, and we want to keep color unclamped.
    float3 gradedColor;
    if (RENODX_TONE_MAP_TYPE > 0.f) {
      gradedColor = combinedRGB;
    } else {
      gradedColor.r = tex2D(TextureGrading, float2(lutUV.r, LUT_V_COORD)).r;
      gradedColor.g = tex2D(TextureGrading, float2(lutUV.g, LUT_V_COORD)).r;
      gradedColor.b = tex2D(TextureGrading, float2(lutUV.b, LUT_V_COORD)).r;
    }
    // Apply Gamma/Curve Power to the LUT result
    gradedColor = pow(gradedColor, g_CurveParams.x);

    float gradedColor_Y = dot(gradedColor, LUMA_WEIGHTS);

    // 3. Add Bloom
    // ------------
    float3 colorWithBloom;

    if (RENODX_TONE_MAP_TYPE > 0.f) {
      colorWithBloom = saturate(bloomColor.rgb * g_BloomTint.rgb) + gradedColor;
    } else {
      colorWithBloom = saturate(bloomColor.rgb * g_BloomTint.rgb + gradedColor);
    }

    // 4. Bleach Bypass & Saturation
    // -----------------------------
    // Pre-Bleach Gamma/Curve
    float3 preBleach = pow(colorWithBloom, g_BleachParams.z);
    float luma = dot(preBleach, LUMA_WEIGHTS);
    // Sample Bleach Ramp based on Luma
    float3 bleachSample = tex2D(TextureBleach, float2(luma, LUT_V_COORD)).rgb;
    float3 bleachResult = lerp(preBleach, bleachSample, g_BleachParams.y);

    // 5. Dynamic Contrast / Luma Correction
    // -------------------------------------
    float contrastNum = max((luma - 0.5f) * g_BleachParams.x + 0.5f, 0.f);

    // Scale = ContrastNum / (Luma + Epsilon)
    float contrastScale = contrastNum / (luma + EPSILON); 
    float3 contrastColor = max(bleachResult * contrastScale, 0.f);

    // 6. Final Levels & Post-Curve
    // ----------------------------
    // Post-Contrast Gamma
    float3 postCurveLog = log2(contrastColor);
    float3 postCurveExp = postCurveLog * g_BleachParams.w;
    float3 postCurve = exp2(postCurveExp);

    // Levels Adjustment
    // (Val - InMin) * Scale + 0.5
    float3 levelsDiff = postCurve - g_Levels.y;
    float3 levelsScale = (levelsDiff >= 0.0f) ? g_Levels.z : g_Levels.x;

    // Final Output
    float3 finalcolor = levelsDiff * levelsScale + 0.5f;


    // LUT for already fully post processed HDR
    float3 lutUVLinear = finalcolor * g_CurveParams.y + LUT_OFFSET;
    float3 gradedColorLinear;
    gradedColorLinear.r = tex2D(TextureGrading, float2(lutUVLinear.r, LUT_V_COORD)).r;
    gradedColorLinear.g = tex2D(TextureGrading, float2(lutUVLinear.g, LUT_V_COORD)).r;
    gradedColorLinear.b = tex2D(TextureGrading, float2(lutUVLinear.b, LUT_V_COORD)).r;

    float3 finalcolorSDR = saturate(gradedColorLinear);
    float3 finalcolorSDRVanilla = saturate(finalcolor);

    float3 untonemapped_gamma = max(0, finalcolor.rgb);
    float3 untonemapped = renodx::color::srgb::Decode(untonemapped_gamma);
    float3 untonemapped_encoded = renodx::color::srgb::Encode(untonemapped);

    if (RENODX_TONE_MAP_TYPE > 0.f) {
      o.rgb = renodx::draw::ToneMapPass(untonemapped_gamma, finalcolorSDR);
    } else {
      o.rgb = finalcolorSDRVanilla.xyz;
    }

    o.a = renodx::color::y::from::BT709(o.rgb);
    o.rgb = renodx::draw::RenderIntermediatePass(o.rgb);

    return float4(o.rgb, o.a);
}