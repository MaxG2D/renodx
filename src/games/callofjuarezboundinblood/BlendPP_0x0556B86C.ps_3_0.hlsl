#include "./shared.h"

// --- Registers ---
float4 CONST_100 : register(c0); // .z = Glow Scale, .w = Tone Scale
float4 CONST_101 : register(c1); // .y, .w = Masking/Saturation Bias
float4 CONST_105 : register(c2); // .w = Color Grade Mix Factor
float4 CONST_109 : register(c3); // Color Grade: Pre-Offset
float4 CONST_110 : register(c4); // Color Grade: Pre-Add / .w = Secondary Tone Offset
float4 CONST_111 : register(c5); // Color Grade: Power (Exponent)
float4 CONST_112 : register(c6); // Color Grade: Post-Scale
float4 CONST_113 : register(c7); // Color Grade: Post-Add / .w = Final Scale Bias
float4 CONST_114 : register(c8); // .x = Overlay Contrast, .y = Overlay Brightness
float4 CONST_70  : register(c9); // .y = Scene Exposure

sampler2D s_clr     : register(s0); // Base Scene
sampler2D s_avg     : register(s1); // Avg Luminance
sampler2D s_msk     : register(s2); // Depth/Object Mask
sampler2D s_overlay : register(s3); // Screen-space Overlay (Grain/Dirt)
sampler2D s_blur    : register(s4); // Blurred Scene
sampler2D s_glow    : register(s5); // Bloom/Glow

float4 main(float2 texcoord : TEXCOORD) : COLOR
{
    // 1. Initial Sampling & Tonemapping
    float avgLuminance = tex2Dlod(s_avg, float4(0,0,0,0)).x;
    float4 clr = tex2D(s_clr, texcoord);
    float4 glow = tex2D(s_glow, texcoord);
    float3 linearColor = clr.rgb * CONST_70.y * avgLuminance;
    float3 untonemapped = linearColor + (glow.rgb * (CONST_100.z * CUSTOM_BLOOM_AMOUNT));
    float3 untonemapped_gamma = renodx::color::gamma::Decode(untonemapped, 2.0);

    float3 processed;
    // Standard Reinhard: (C * (1 + C*w)) / (1 + C)
    processed = (linearColor * (linearColor * CONST_100.w + 1.0)) / (linearColor + 1.0);
    processed = sqrt(max(0, processed)); // Gamma 2.0 approx

    // 2. Blur and Masking Blends
    float4 msk = tex2D(s_msk, texcoord);
    float4 blur = tex2D(s_blur, texcoord);
    
    float blurMask = saturate(msk.a * 2.0 - 1.0);
    float3 sceneMix = lerp(processed, blur.rgb, blurMask);
    
    // Advanced masking logic using Alpha
    float alphaMask = saturate(clr.a * -CONST_101.y + CONST_101.y);
    float finalMask = saturate(max(max(blur.a, msk.z), alphaMask));
    
    float3 composition = lerp(sceneMix, blur.rgb, finalMask);

    // 3. Saturation
    float luma = dot(composition, 0.33333334);
    float3 saturated = lerp(composition, luma, alphaMask);
    float3 prefinalColor = lerp(composition, saturated, CUSTOM_CHROMACITY_EFFECTS_STRENGTH);

    // 4. Color Grading Block (The Log/Exp "Power" Math)
    // result = pow(saturate(color * c3 + c4), c5) * c6 + c7
    float3 gradeA = (RENODX_TONE_MAP_TYPE > 0.f) ? (prefinalColor * CONST_109.rgb + CONST_110.rgb) : saturate(prefinalColor * CONST_109.rgb + CONST_110.rgb);
    gradeA = pow(gradeA, CONST_111.rgb) * CONST_112.rgb + CONST_113.rgb;
    
    // Mix the color grade back
    float gradeWeight = saturate(clr.a * -CONST_105.w + CONST_105.w);
    float3 gradedScene = lerp(prefinalColor, gradeA, gradeWeight);

    // 5. Secondary Pass / Gamma
    // Another pow() operation using c5.w
    float3 gradeB = (RENODX_TONE_MAP_TYPE > 0.f) ? (gradedScene * gradedScene.rgb + CONST_110.w) : saturate(gradedScene * gradedScene.rgb + CONST_110.w); 
    gradeB = pow(gradeB, CONST_111.www) * 1.0 + CONST_113.www;
    
    float mixB = clr.a * CONST_105.w;
    float3 finalScene = lerp(gradedScene, gradeB, mixB);

    // 6. Glow and Overlay
    float3 withGlow = (RENODX_TONE_MAP_TYPE > 0.f) ? (glow.rgb * (CONST_100.z * CUSTOM_BLOOM_AMOUNT) + finalScene) : saturate(glow.rgb * CONST_100.z + finalScene);

    // Sample overlay (Film grain/Dirt)
    float4 overlay = tex2Dlod(s_overlay, float4(texcoord, 0, 0));
    float3 overlayFinal = (RENODX_TONE_MAP_TYPE > 0.f) ? (overlay.rgb * CONST_114.x + CONST_114.y) : saturate(overlay.rgb * CONST_114.x + CONST_114.y);

    float4 output;

    float3 vanilla = saturate(withGlow * overlayFinal);
    untonemapped_gamma = renodx::draw::ComputeUntonemappedGraded(untonemapped_gamma, vanilla.xyz);
    float3 tonemapped = renodx::tonemap::renodrt::NeutralSDR(untonemapped_gamma);
    tonemapped = renodx::color::gamma::Encode(tonemapped, 2.0);
    if (RENODX_TONE_MAP_TYPE > 0.f) {
      output.xyz = renodx::draw::ToneMapPass(untonemapped, vanilla.xyz, tonemapped);
    }
    else {
      output.xyz = saturate(vanilla);
    }
    output.w = clr.a;

    return output;
}