//
// Optimized & Readable Post-Processing Shader
// Refactored from legacy ASM logic
//
#include "./shared.h"

// Output shader
sampler2D TextureBase     : register(s0); // s0: Main Render
sampler2D TextureBloom    : register(s1); // s1: Bloom Buffer
sampler2D TextureGrading  : register(s2); // s2: 1D Color Grading LUT
sampler2D TextureExposure : register(s3); // s3: Exposure Weight
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
    // Using BT.709 Luma Weights (standard for this pipeline)
    const float3 LUMA_WEIGHTS = float3(0.2126f, 0.7152f, 0.0722f); 
    const float  LUT_OFFSET   = 0.00048828125f;
    const float  LUT_V_COORD  = 0.03125f;
    const float  EPSILON      = 1e-7;

    // 1. Texture Composition
    // ----------------------
    float4 o            = float4(0, 0, 0, 1);
    float4 baseColor    = tex2D(TextureBase, input.uv);
    float4 overlayColor = tex2D(TextureOverlay, input.uv);
    float4 exposure     = tex2D(TextureExposure, float2(LUT_V_COORD, 0.0f));
    float4 bloomColor   = tex2D(TextureBloom, input.uv);

    // Combine Base and Overlay
    float3 composition = overlayColor.w * baseColor.rgb + overlayColor.rgb;

    // Apply Exposure Weighting
    float3 exposuremultipliedLinearColor = composition.rgb * exposure.x;
    float originalLuma = dot(exposuremultipliedLinearColor, LUMA_WEIGHTS);

    // 2. Color Grading (Luminance-Preserving LUT Lookup)
    // --------------------------------------------------
    float3 gradedColor = exposuremultipliedLinearColor;
    float3 lutUV = exposuremultipliedLinearColor * g_CurveParams.y + LUT_OFFSET;
    /*
        if (RENODX_TONE_MAP_TYPE > 0.f) {
        
        // FIX 1: Apply LUT in HDR path to match SDR colors, but preserve Luminance
        // to prevent the LUT from clamping/darkening the HDR range.
        float3 gradedColorRaw;
        gradedColorRaw.r = tex2D(TextureGrading, float2(lutUV.r, LUT_V_COORD)).r;
        gradedColorRaw.g = tex2D(TextureGrading, float2(lutUV.g, LUT_V_COORD)).r;
        gradedColorRaw.b = tex2D(TextureGrading, float2(lutUV.b, LUT_V_COORD)).r;
        float gradedColorRawLuma = dot(gradedColorRaw, LUMA_WEIGHTS);

        // Apply the Color of the LUT, but scale it to match the Input Luminance
        if (gradedColorRawLuma > EPSILON) {
          gradedColor = gradedColorRaw * (originalLuma / gradedColorRawLuma);
          gradedColor = pow(gradedColorRaw, g_CurveParams.x);
        } else {
          gradedColor = exposuremultipliedLinearColor;
          gradedColor = pow(gradedColor, g_CurveParams.x);
        }

          //
          //  gradedColor.r = tex2D(TextureGrading, float2(lutUV.r, LUT_V_COORD)).r;
          //  gradedColor.g = tex2D(TextureGrading, float2(lutUV.g, LUT_V_COORD)).r;
          //  gradedColor.b = tex2D(TextureGrading, float2(lutUV.b, LUT_V_COORD)).r;
          //
        } else {
            // SDR Path: Direct LUT application
            gradedColor.r = tex2D(TextureGrading, float2(lutUV.r, LUT_V_COORD)).r;
            gradedColor.g = tex2D(TextureGrading, float2(lutUV.g, LUT_V_COORD)).r;
            gradedColor.b = tex2D(TextureGrading, float2(lutUV.b, LUT_V_COORD)).r;
            // Apply Gamma/Curve Power to the LUT result
            gradedColor = pow(gradedColor, g_CurveParams.x);
        }
    */

    if (RENODX_TONE_MAP_TYPE <= 0.f) {
          gradedColor.r = tex2D(TextureGrading, float2(lutUV.r, LUT_V_COORD)).r;
          gradedColor.g = tex2D(TextureGrading, float2(lutUV.g, LUT_V_COORD)).r;
          gradedColor.b = tex2D(TextureGrading, float2(lutUV.b, LUT_V_COORD)).r;
          //gradedColor = pow(gradedColor, g_CurveParams.x);
    }

    float3 GammaColor = pow(gradedColor, g_CurveParams.x);
    //float3 GammaColor = gradedColor;

    // 3. Add Bloom
    // ------------
    float3 colorWithBloom;
    float3 bloomAdjusted = bloomColor.rgb * g_BloomTint.rgb;

    if (RENODX_TONE_MAP_TYPE > 0.f) {
      colorWithBloom = (bloomAdjusted * Custom_Bloom_Amount) + GammaColor;
    } else {
      colorWithBloom = saturate(bloomAdjusted + GammaColor);
    }

    // 4. Bleach Bypass & Saturation
    // -----------------------------
    float3 preBleach = pow(colorWithBloom, g_BleachParams.z);
    float luma = dot(preBleach, LUMA_WEIGHTS);
    
    float3 bleachSample = tex2D(TextureBleach, float2(luma, LUT_V_COORD)).rgb;
    
    float3 bleachResult;
    if (RENODX_TONE_MAP_TYPE > 0.f) {
      bleachResult = lerp(preBleach, bleachSample, g_BleachParams.y * Custom_Color_Desaturation);
    } else {
      bleachResult = lerp(preBleach, bleachSample, g_BleachParams.y);
    }

    // 5. Dynamic Contrast / Luma Correction (HDR Fix)
    // -----------------------------------------------
    // Calculation: (Luma - 0.5) * Contrast + 0.5
    float contrastNum = (luma - 0.5f) * g_BleachParams.x + 0.5f;

    // FIX 2: In SDR, contrastNum is hard-clamped to 1.0. In HDR, we must replicate this 
    // behavior for the 0-1 range to match brightness (fixing the "Too Bright" issue).
    // We soft-clamp contrastNum to not exceed the input luma itself for highlights > 1.0.
    if (RENODX_TONE_MAP_TYPE > 0.f) {
        contrastNum = min(contrastNum, max(1.0f, luma));
    } else {
        contrastNum = saturate(contrastNum);
    }

    float contrastScale = contrastNum / (luma + EPSILON);
    
    float3 contrastColor;
    if (RENODX_TONE_MAP_TYPE > 0.f) {
      // Apply Custom_Color_Contrast as a multiplier (default 1.0 should now match SDR)
      contrastColor = lerp(bleachResult, max(bleachResult * contrastScale * Custom_Color_Contrast, 0.f), clamp(Custom_Color_Contrast, 0.f, 1.f)); 
    } else {
      contrastColor = saturate(bleachResult * contrastScale);
    }

    // 6. Final Levels & Post-Curve
    // ----------------------------
    float3 postCurveLog = log2(contrastColor);
    float3 postCurveExp = postCurveLog * g_BleachParams.w;
    float3 postCurve = exp2(postCurveExp);

    float3 levelsDiff;
    if (RENODX_TONE_MAP_TYPE > 0.f) {
        // Apply Custom_Color_Levels logic
        levelsDiff = postCurve - (g_Levels.y * Custom_Color_Levels);
    } else {
        levelsDiff = postCurve - g_Levels.y;
    }
    
    float3 levelsScale = (levelsDiff >= 0.0f) ? g_Levels.z : g_Levels.x;
    
    float3 prefinalcolor;
    if (RENODX_TONE_MAP_TYPE > 0.f) {
      prefinalcolor = levelsDiff * (levelsScale * Custom_Color_Levels) + 0.5f;
    } else {
      prefinalcolor = levelsDiff * (levelsScale) + 0.5f;
    }

    // 7. Final Output
    // ---------------
    float3 unclampedgradedColor = prefinalcolor;
    float3 unclampedlutUV = unclampedgradedColor * g_CurveParams.y + LUT_OFFSET;
    unclampedgradedColor.r = tex2D(TextureGrading, float2(unclampedlutUV.r, LUT_V_COORD)).r;
    unclampedgradedColor.g = tex2D(TextureGrading, float2(unclampedlutUV.g, LUT_V_COORD)).r;
    unclampedgradedColor.b = tex2D(TextureGrading, float2(unclampedlutUV.b, LUT_V_COORD)).r;
    //unclampedgradedColor = pow(unclampedgradedColor, 1 / g_CurveParams.x);

    float3 finalcolorSDRVanilla = saturate(prefinalcolor);
    float3 untonemappedGameGamma = pow(prefinalcolor, 1 / g_CurveParams.x);
    float3 untonemapped = max(0, prefinalcolor.rgb);
    float3 untonemapped_Decode = renodx::color::srgb::Decode(untonemapped);
    float3 untonemapped_Encode = renodx::color::srgb::Encode(untonemapped);
    float3 tonemapped = renodx::tonemap::renodrt::NeutralSDR(untonemapped);
    float3 tonemapped_Decode = renodx::color::srgb::Decode(tonemapped);
    float3 tonemapped_Encode = renodx::color::srgb::Encode(tonemapped);

    if (RENODX_TONE_MAP_TYPE > 0.f) {
      o.rgb = renodx::draw::ToneMapPass(untonemapped, unclampedgradedColor);
    } else {
      o.rgb = finalcolorSDRVanilla.xyz;
    }

    o.a = renodx::color::y::from::BT709(o.rgb);
    o.rgb = renodx::draw::RenderIntermediatePass(o.rgb);

    return float4(o.rgb, o.a);
}