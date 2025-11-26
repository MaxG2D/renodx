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

    // 2. Color Grading
    // --------------------------------------------------
    float3 gradedColor = exposuremultipliedLinearColor;
    float3 lutUV = exposuremultipliedLinearColor * g_CurveParams.y + LUT_OFFSET;
    if (RENODX_TONE_MAP_TYPE <= 0.f) {
          gradedColor.r = tex2D(TextureGrading, float2(lutUV.r, LUT_V_COORD)).r;
          gradedColor.g = tex2D(TextureGrading, float2(lutUV.g, LUT_V_COORD)).r;
          gradedColor.b = tex2D(TextureGrading, float2(lutUV.b, LUT_V_COORD)).r;
          gradedColor = pow(gradedColor, g_CurveParams.x);
    }
    float3 GammaColor = gradedColor;

    // 3. Add Bloom
    // ------------
    float3 colorWithBloom;
    float3 bloomAdjusted = bloomColor.rgb * g_BloomTint.rgb;
    float3 linearWithBloom = GammaColor + bloomAdjusted;

    if (RENODX_TONE_MAP_TYPE > 0.f) {
      colorWithBloom = (bloomAdjusted * Custom_Bloom_Amount) + GammaColor;
    } else {
      colorWithBloom = saturate(bloomAdjusted + GammaColor);
    }

    // 4. Bleach (Desaturation)
    // -----------------------------
    // FIX: Ensure input to pow is not negative (possible in HDR manipulation)
    float3 preBleach;
    if (Custom_Bypass_GameProcessing > 0.f && RENODX_TONE_MAP_TYPE > 0.f) {
      preBleach = colorWithBloom;
    } else {
      preBleach = pow(max(colorWithBloom, 0.f), g_BleachParams.z);
    }
    float luma = dot(preBleach, LUMA_WEIGHTS);
    
    float3 bleachSample = tex2D(TextureBleach, float2(luma, LUT_V_COORD)).rgb;
    
    float3 bleachResult;
    if (RENODX_TONE_MAP_TYPE > 0.f) {
        if (Custom_Bypass_GameProcessing > 0.f) {
          bleachResult = preBleach;
        } else {
          bleachResult = lerp(preBleach, bleachSample, g_BleachParams.y * Custom_Color_Desaturation);
        }
    } else {
        bleachResult = lerp(preBleach, bleachSample, g_BleachParams.y);
    }

    // 5. Contrast
    // -----------------------------------------------
    // Calculation: (Luma - 0.5) * Contrast + 0.5
    float contrastNum;
    if (RENODX_TONE_MAP_TYPE > 0.f) {
      luma = pow((saturate(luma)), g_CurveParams.x);
        contrastNum = (luma - 0.5f) * g_BleachParams.x + 0.5f;
        contrastNum = max(contrastNum, 0.f);
    } else {
        contrastNum = (luma - 0.5f) * g_BleachParams.x + 0.5f;
        contrastNum = saturate(contrastNum);
    }

    float contrastScale = max(contrastNum / (luma + EPSILON), 0.f);
    
    float3 contrastColor;
    if (RENODX_TONE_MAP_TYPE > 0.f) {
      if (Custom_Bypass_GameProcessing > 0.f) {
        contrastColor = bleachResult;
      } else {
        float3 contrastScaleMixed = max((bleachResult) * (contrastScale * (1.f - Custom_Color_Contrast + 1.f)), 0.f);
        contrastColor = lerp(bleachResult, contrastScaleMixed, clamp(Custom_Color_Contrast, 0.f, 1.f));
      }
    } else {
        contrastColor = saturate(bleachResult * contrastScale);
    }

    // 6. Final Levels & Post-Curve
    // ----------------------------
    float3 postCurve;
    //if (Custom_Bypass_GameProcessing == 0.f || RENODX_TONE_MAP_TYPE == 0.f) {
      float3 postCurveLog = log2(max(contrastColor, EPSILON));
      float3 postCurveExp = postCurveLog * g_BleachParams.w;
      postCurve = exp2(postCurveExp);
    //} else {
    //  postCurve = contrastColor;
    //}

    float3 levelsDiff;
    if (RENODX_TONE_MAP_TYPE > 0.f) {
      if (Custom_Bypass_GameProcessing > 0.f) {
        levelsDiff = postCurve;
      } else {
        levelsDiff = postCurve - (g_Levels.y * Custom_Color_Levels);
      }
    } else {
        levelsDiff = postCurve - g_Levels.y;
    }
    float3 levelsScale;
    if (RENODX_TONE_MAP_TYPE > 0.f) {
        levelsScale = (levelsDiff >= 0.0f) ? g_Levels.z * Custom_Color_Levels : g_Levels.x;
    } else {
        levelsScale = (levelsDiff >= 0.0f) ? g_Levels.z : g_Levels.x;
    }
    float3 prefinalcolor; 
    if (Custom_Bypass_GameProcessing > 0.f && RENODX_TONE_MAP_TYPE > 0.f) {
      prefinalcolor = levelsDiff;
    } else {
      prefinalcolor = levelsDiff * (levelsScale) + 0.5f;
    }
    // 7. Final Output
    // ---------------
    float3 unclampedgradedColor = prefinalcolor;
    if (Custom_Bypass_GameProcessing <= 0) {
      float3 unclampedlutUV = unclampedgradedColor * g_CurveParams.y + LUT_OFFSET;
      unclampedgradedColor.r = tex2D(TextureGrading, float2(unclampedlutUV.r, LUT_V_COORD)).r;
      unclampedgradedColor.g = tex2D(TextureGrading, float2(unclampedlutUV.g, LUT_V_COORD)).r;
      unclampedgradedColor.b = tex2D(TextureGrading, float2(unclampedlutUV.b, LUT_V_COORD)).r;
    }
    float3 finalcolorSDR = unclampedgradedColor;
    if (Custom_Bypass_GameProcessing > 0.f) {
      finalcolorSDR = pow(max(finalcolorSDR, 0.f), g_CurveParams.x);
    } else {
      finalcolorSDR = pow(max(finalcolorSDR, 0.f), g_CurveParams.x);
      
    }
    finalcolorSDR = saturate(finalcolorSDR);
    float3 finalcolorSDRVanilla = saturate(prefinalcolor);

    // float3 untonemappedNoGameGamma = pow(prefinalcolor, 1 / g_CurveParams.x);
    // float3 GradedNoGamaGamma = pow(unclampedgradedColor, 1 / g_CurveParams.x);

    float3 untonemapped;
    float3 untonemapped_Encode;
    if (Custom_Bypass_GameProcessing > 0.f) {
      // untonemapped = pow(max(prefinalcolor, 0.f), g_CurveParams.x);
      untonemapped = renodx::color::srgb::Encode(prefinalcolor); 
    } else {
      untonemapped = pow(max(prefinalcolor, 0.f), g_CurveParams.x);
    }
    float3 untonemapped_Decode = renodx::color::srgb::Decode(untonemapped);
    //float3 untonemapped_Encode = renodx::color::srgb::Encode(untonemapped);
    float3 tonemapped = renodx::tonemap::renodrt::NeutralSDR(untonemapped_Decode);
    float3 tonemapped_Decode = renodx::color::srgb::Decode(tonemapped);
    float3 tonemapped_Encode = renodx::color::srgb::Encode(tonemapped);

    if (Custom_Bypass_GameProcessing > 0.f) {
      //tonemapped = pow(tonemapped, 1 / g_CurveParams.x);
      tonemapped = tonemapped_Encode;
    } else {
      tonemapped = tonemapped_Encode;
    }

    if (RENODX_TONE_MAP_TYPE > 0.f) {
      o.rgb = renodx::draw::ToneMapPass(untonemapped, finalcolorSDR, tonemapped);
    } else {
      o.rgb = finalcolorSDRVanilla.xyz;
    }

    o.a = renodx::color::y::from::BT709(o.rgb);
    o.rgb = renodx::draw::RenderIntermediatePass(o.rgb);

    return float4(o.rgb, o.a);
}