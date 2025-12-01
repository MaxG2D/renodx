//#include "../../shaders/tonemap.hlsl"
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
    renodx::tonemap::Config config = renodx::tonemap::config::Create();
    config.type = RENODX_TONE_MAP_TYPE;
    config.peak_nits = RENODX_PEAK_WHITE_NITS;
    config.game_nits = RENODX_DIFFUSE_WHITE_NITS;
    config.gamma_correction = RENODX_GAMMA_CORRECTION;
    config.exposure = RENODX_TONE_MAP_EXPOSURE;
    config.highlights = RENODX_TONE_MAP_HIGHLIGHTS;
    config.shadows = RENODX_TONE_MAP_SHADOWS;
    config.contrast = RENODX_TONE_MAP_CONTRAST;
    config.saturation = RENODX_TONE_MAP_SATURATION;
    config.mid_gray_value = 0.18;
    config.mid_gray_nits = 0.18 * 100.f;
    config.reno_drt_dechroma = RENODX_TONE_MAP_BLOWOUT;
    
    // Constants
    const float3 LUMA_WEIGHTS = float3(0.2126f, 0.7152f, 0.0722f); 
    const float  LUT_OFFSET   = 0.00048828125f;
    const float  LUT_V_COORD  = 0.03125f;
    const float  EPSILON      = 1e-7;

    // Texture Composition
    float4 o            = float4(0, 0, 0, 1);
    float4 baseColor    = tex2D(TextureBase, input.uv);
    float4 overlayColor = tex2D(TextureOverlay, input.uv);
    float4 exposure     = tex2D(TextureExposure, float2(LUT_V_COORD, 0.0f));
    float4 bloomColor   = tex2D(TextureBloom, input.uv);

    float3 composition = overlayColor.w * baseColor.rgb + overlayColor.rgb;
    float3 exposuremultipliedLinearColor = composition.rgb * exposure.x;
    float3 linearWithBloom = exposuremultipliedLinearColor.rgb + ((bloomColor.rgb * g_BloomTint.rgb) * Custom_Bloom_Amount);

    // Color Grading
    float3 gradedColor = exposuremultipliedLinearColor;
    float3 lutUV = exposuremultipliedLinearColor * g_CurveParams.y + LUT_OFFSET;
    gradedColor.r = tex2D(TextureGrading, float2(lutUV.r, LUT_V_COORD)).r;
    gradedColor.g = tex2D(TextureGrading, float2(lutUV.g, LUT_V_COORD)).r;
    gradedColor.b = tex2D(TextureGrading, float2(lutUV.b, LUT_V_COORD)).r;
    gradedColor = pow(gradedColor, g_CurveParams.x);
    float3 GammaColor = gradedColor;

    // Add Bloom
    float3 colorWithBloom;
    float3 bloomAdjusted = bloomColor.rgb * g_BloomTint.rgb;

    if (RENODX_TONE_MAP_TYPE > 0.f) {
      colorWithBloom = (bloomAdjusted * Custom_Bloom_Amount) + GammaColor;
    } else {
      colorWithBloom = saturate(bloomAdjusted + GammaColor);
    }

    // Bleach (Desaturation)
    float3 preBleach;
    preBleach = pow(max(colorWithBloom, 0.f), g_BleachParams.z);
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

    // Contrast Adjustment
    float contrastNum;
    if (RENODX_TONE_MAP_TYPE > 0.f) {
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

    // Final Levels & Post-Curve
    float3 postCurve;
    float3 postCurveLog = log2(max(contrastColor, 0.f));
    float3 postCurveExp = postCurveLog * g_BleachParams.w;
    postCurve = exp2(postCurveExp);

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
        levelsScale = (levelsDiff >= 0.0f) ? g_Levels.z * Custom_Color_Levels : g_Levels.x * Custom_Color_Levels;
    } else {
        levelsScale = (levelsDiff >= 0.0f) ? g_Levels.z : g_Levels.x;
    }
    float3 prefinalcolor; 
    if (Custom_Bypass_GameProcessing > 0.f && RENODX_TONE_MAP_TYPE > 0.f) {
      prefinalcolor = levelsDiff;
    } else {
      prefinalcolor = levelsDiff * (levelsScale) + 0.5f;
    }

    float3 finalcolorSDR = prefinalcolor;
    //finalcolorSDR = renodx::color::correct::GammaSafe(finalcolorSDR, true, 2.2f);
    finalcolorSDR = saturate(finalcolorSDR);
    float3 finalcolorSDRVanilla = saturate(prefinalcolor);

    float3 untonemapped = max(linearWithBloom, 0.f);
    untonemapped = pow(max(untonemapped, 0.f), g_CurveParams.x);
    untonemapped = pow(max(untonemapped, 0.f), g_BleachParams.z);
    //untonemapped = log2(max(untonemapped, 0.f));
    untonemapped = untonemapped * 1/g_BleachParams.w;
    //untonemapped = exp2(untonemapped);
    untonemapped = renodx::color::srgb::Decode(untonemapped);
    float3 untonemapped_Decode = renodx::color::srgb::Decode(untonemapped);
    float3 untonemapped_Encode = renodx::color::srgb::Encode(untonemapped);
    float3 tonemapped = renodx::tonemap::renodrt::NeutralSDR(untonemapped_Decode);
    float3 tonemapped_Decode = renodx::color::srgb::Decode(tonemapped);
    float3 tonemapped_Encode = renodx::color::srgb::Encode(tonemapped);
    tonemapped_Encode = renodx::color::correct::GammaSafe(tonemapped_Encode, false, 2.2f);

    if (RENODX_TONE_MAP_TYPE > 0.f && RENODX_TONE_MAP_TYPE != 2.f) {
      o.rgb = renodx::draw::ToneMapPass(untonemapped, finalcolorSDR, tonemapped_Encode);
    } else if (RENODX_TONE_MAP_TYPE == 0.f){
      o.rgb = finalcolorSDRVanilla.xyz;
    } else if (RENODX_TONE_MAP_TYPE == 2.f) {
      untonemapped = renodx::color::grade::UserColorGrading(
          untonemapped,
          config.exposure,
          config.highlights,
          config.shadows,
          config.contrast,
          config.saturation);
      float3 AcesUntonemapped = renodx::tonemap::config::ApplyACES(untonemapped_Decode, config);
      float3 Acestonemapped = renodx::tonemap::config::ApplyACES(untonemapped_Decode, config, true);
      Acestonemapped = renodx::color::srgb::Encode(Acestonemapped);
      o.rgb = renodx::tonemap::UpgradeToneMap(AcesUntonemapped, Acestonemapped, finalcolorSDR, RENODX_COLOR_GRADE_STRENGTH);
      //o.rgb = AcesUntonemapped;
    }

    o.a = renodx::color::y::from::BT709(o.rgb);
    o.rgb = renodx::draw::RenderIntermediatePass(o.rgb);

    return float4(o.rgb, o.a);
}