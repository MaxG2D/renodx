#include "./shared.h"

// --- Constant Registers ---
float4 GlowParams      : register(c0); // .z = Glow Strength, .w = Reinhard Scale (White Point)
float4 SaturationParams : register(c1); // .w = Saturation (0 = B&W, 1 = Full Color)
float4 ColorScaling    : register(c2); // .y = Global Exposure/Brightness Multiplier

// --- Textures ---
sampler2D s_BaseColor : register(s0); // The main rendered frame
sampler2D s_AvgLum    : register(s1); // Average scene luminance (1x1 texture)
sampler2D s_Mask      : register(s2); // Depth/UI Mask (Alpha = Bloom/DOF blend)
sampler2D s_Blur      : register(s3); // Blurred version of the frame
sampler2D s_Glow      : register(s4); // Bloom/Glow additive texture

// --- Settings ---

float4 main(float2 texcoord : TEXCOORD) : COLOR
{
    // 1. Fetch Raw Data
    float4 baseColor = tex2D(s_BaseColor, texcoord);
    float4 glow = tex2D(s_Glow, texcoord);
    float avgLuminance = tex2Dlod(s_AvgLum, float4(0, 0, 0, 0)).x;
    
    // 2. Initial Exposure Scaling (Legacy CONST_70.y)
    // The "World" color before any tone compression
    float3 linearColor = baseColor.rgb;
    //float3 linearColor = baseColor.rgb  * ColorScaling.y * avgLuminance;
    linearColor = linearColor * ColorScaling.y;
    linearColor = linearColor * avgLuminance;
    float3 untonemapped = linearColor + (glow.rgb * GlowParams.z * CUSTOM_BLOOM_AMOUNT);
    float3 untonemapped_gamma = renodx::color::gamma::Decode(untonemapped, 2.0);

    // 3. The Tonemapping Logic
    float3 processedColor;

    /* Legacy Reinhard Formula (Per-Channel):
        (Color * (1 + Color * WhitePoint)) / (1 + Color)
        Then followed by a Sqrt (Gamma 2.0 approximation)
    */
    float3 numerator = linearColor * (linearColor * GlowParams.w + 1.0);
    float3 denominator = linearColor + 1.0;
    float3 reinhard = numerator / denominator;
    
    // Final Legacy Step: Inverse Gamma (Approximated by Sqrt)
    processedColor = sqrt(max(0.f, reinhard));

    // 4. Bloom/Blur Masking Logic
    float4 mask = tex2D(s_Mask, texcoord);
    float4 blur = tex2D(s_Blur, texcoord);
    
    // Threshold the mask (Legacy: msk.a * 2 - 1)
    float blurMask = saturate(mask.a * 2.0 - 1.0);
    
    // Blend between sharp tonemapped image and blurred image
    float3 blendedScene = lerp(processedColor, blur.rgb, blurMask);
    
    // Secondary mask check (Legacy: max(blur.a, mask.z))
    float secondaryMask = max(blur.a, mask.z);
    blendedScene = lerp(blendedScene, blur.rgb, secondaryMask);

    // 5. Saturation / Grayscale
    // Legacy conversion using 0.333 (Simple Average) instead of Rec.709 Luma
    float luma = dot(blendedScene, 0.33333334);
    // float luma = dot(blendedScene, float3(0.2126f, 0.7152f, 0.0722f));
    float3 saturatedColor = lerp(blendedScene, luma, SaturationParams.w);
    float3 prefinalColor = lerp(blendedScene, saturatedColor, CUSTOM_CHROMACITY_EFFECTS_STRENGTH);

    float4 output;

    float3 vanilla = saturate((glow.rgb * GlowParams.z * CUSTOM_BLOOM_AMOUNT) + (prefinalColor));
    untonemapped_gamma = renodx::draw::ComputeUntonemappedGraded(untonemapped_gamma, vanilla.xyz);
    float3 tonemapped = renodx::tonemap::renodrt::NeutralSDR(untonemapped_gamma);
    tonemapped = renodx::color::gamma::Encode(tonemapped, 2.0);
    if (RENODX_TONE_MAP_TYPE > 0.f) {
      output.xyz = renodx::draw::ToneMapPass(untonemapped, vanilla.xyz, tonemapped);
    }
    else {
      output.xyz = saturate(vanilla);
    }
    output.w = baseColor.a;

    return output;
}