#include "../../shaders/tonemap.hlsl"
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

    // Texture Composition
    float4 o            = float4(0, 0, 0, 1);
    float4 baseColor    = tex2D(TextureBase, input.uv);
    float4 overlayColor = tex2D(TextureOverlay, input.uv);
    float4 exposure     = tex2D(TextureExposure, float2(LUT_V_COORD, 0.0f));
    float4 bloomColor   = tex2D(TextureBloom, input.uv);

    float3 composition = overlayColor.w * baseColor.rgb + overlayColor.rgb;
    //float3 composition = baseColor.rgb;
    float3 exposuremultipliedLinearColor = composition.rgb * exposure.x;

    // Moved Bloom at the start of the pipieline in untonemapped compared to vanilla to avoid clipping issues

    float3 bloomRaw = bloomColor.rgb * g_BloomTint.rgb * Custom_Bloom_Amount;
    float3 linearWithBloom = exposuremultipliedLinearColor.rgb + (bloomRaw);
    float preLUT_luma = dot(linearWithBloom, LUMA_WEIGHTS);

    // Color Grading
    float3 gradedColor = exposuremultipliedLinearColor;
    float3 lutUV = exposuremultipliedLinearColor * g_CurveParams.y + LUT_OFFSET;
    gradedColor.r = tex2D(TextureGrading, float2(lutUV.r, LUT_V_COORD)).r;
    gradedColor.g = tex2D(TextureGrading, float2(lutUV.g, LUT_V_COORD)).r;
    gradedColor.b = tex2D(TextureGrading, float2(lutUV.b, LUT_V_COORD)).r;
    gradedColor = pow(gradedColor, g_CurveParams.x);
    float3 GammaColor = gradedColor;
    float postLUT_luma = dot(GammaColor + bloomColor.rgb * g_BloomTint.rgb * Custom_Bloom_Amount, LUMA_WEIGHTS);
    float lutRatio = saturate(postLUT_luma / preLUT_luma);

    // Add Bloom
    float3 colorWithBloom;
    float3 bloomAdjusted;

    if (Custom_Bloom_Improve != 0) {
      colorWithBloom = GammaColor;
    } else {
      bloomAdjusted = bloomColor.rgb * g_BloomTint.rgb;
      colorWithBloom = saturate(bloomAdjusted + GammaColor);
    }

    // Bleach (Desaturation)
    float3 preBleach;
    preBleach = pow(max(colorWithBloom, 0.f), g_BleachParams.z);
    float luma = dot(preBleach, LUMA_WEIGHTS);
    
    float3 bleachSample = tex2D(TextureBleach, float2(luma, LUT_V_COORD)).rgb;
    
    float3 bleachResult;
    if (RENODX_TONE_MAP_TYPE > 0.f) {
        bleachResult = lerp(preBleach, bleachSample, g_BleachParams.y * Custom_Color_Desaturation);
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

    float contrastScale = max(contrastNum / (luma + EPSILON), 0.f) - EPSILON;
    
    float3 contrastColor;
    if (RENODX_TONE_MAP_TYPE > 0.f) {
        float3 contrastScaleMixed = max(bleachResult * (contrastScale * ((1.f - Custom_Color_Contrast) + 1.f)), 0.f);
        contrastColor = lerp(bleachResult, contrastScaleMixed, clamp(Custom_Color_Contrast, 0.f, 1.f));
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
      levelsDiff = postCurve - (g_Levels.y * Custom_Color_Levels);
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
    prefinalcolor = levelsDiff * (levelsScale) + 0.5f;

    if (Custom_Bloom_Improve != 0) {
      // Move bloom down to the very end of the pipeline to avoid it getting griefed by various post processing effects
      // Still, some grading needs to be applied to bloom to match vanilla luminance levels.
      float3 bloomLinear = bloomColor.rgb * g_BloomTint.rgb * Custom_Bloom_Amount;
      bloomLinear = pow(max(bloomLinear, 0.f), g_CurveParams.x);
      bloomLinear = pow(max(bloomLinear, 0.f), g_BleachParams.z);

      // No desaturation on bloom, it effectively causes double desaturation. Sad consequence of fixing the cursed pipeline of vanilla game :(
      //bloomLinearPreBleach = lerp(bloomLinearPreBleach, bleachSample, g_BleachParams.y * Custom_Color_Desaturation);

      // We want the bloom to stay linear, but luminance curve needs to match vanilla
      float3 bloomAdjusted = bloomLinear * 1 / g_BleachParams.w;
      bloomAdjusted = lerp(bloomAdjusted, bloomAdjusted * lutRatio, saturate(preLUT_luma));  // Custom to reduce the excessive clipping from vanilla post process
      // Scaling bloom amount based on luminance difference between the pre and post graded image to avoid overbrightening
      bloomAdjusted *= lutRatio;
      bloomAdjusted = renodx::color::srgb::Decode(bloomAdjusted);
      prefinalcolor += bloomAdjusted;
    }

    float3 finalcolorSDR = prefinalcolor;
    float3 finalcolorSDRVanilla = saturate(prefinalcolor);

    float3 untonemapped = max(linearWithBloom, 0.f);
    untonemapped = pow(max(untonemapped, 0.f), g_CurveParams.x);
    untonemapped = pow(max(untonemapped, 0.f), g_BleachParams.z);
    untonemapped = untonemapped * 1/g_BleachParams.w;
    float3 untonemappedDecoded = renodx::color::srgb::Decode(untonemapped);
    float3 tonemapped = renodx::tonemap::renodrt::NeutralSDR(untonemappedDecoded, true);

    if (RENODX_TONE_MAP_TYPE == 0.f) {   
      o.rgb = finalcolorSDRVanilla.xyz;
    } else if (RENODX_TONE_MAP_TYPE > 1.f) {
      o.rgb = untonemappedDecoded;
    } else if (RENODX_TONE_MAP_TYPE == 1.f) {
      o.rgb = renodx::draw::ToneMapPass(untonemappedDecoded, finalcolorSDR, tonemapped);
    }
    o.a = renodx::color::y::from::BT709(o.rgb);
    o.rgb = renodx::draw::RenderIntermediatePass(o.rgb);
    //o.rgb = renodx::color::srgb::DecodeSafe(o.rgb);
    //o.rgb = renodx::color::correct::GammaSafe(o.rgb, false, 2.2f);

    return float4(o.rgb, o.a);
}