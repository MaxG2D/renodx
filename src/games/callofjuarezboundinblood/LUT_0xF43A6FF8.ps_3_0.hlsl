#include "./shared.h"

float4 CONST_103 : register( c0 ); // .x = Scale/Contrast, .y = Bias/Brightness, .z = Saturation
sampler2D s_tex  : register( s0 ); // The main image
sampler2D s_crv  : register( s1 ); // The 1D Curve Texture

float4 main(float2 texcoord : TEXCOORD) : COLOR
{
    // Sample original HDR image
    float4 originalImage = tex2Dlod(s_tex, float4(texcoord, 0, 0));
    float3 originalHDR = originalImage.xyz;

    // Sample the 1D Curve (This clamps the data based on the curve texture)
    float3 gradedSDR;
    gradedSDR.x = tex2D(s_crv, float2(originalHDR.x, 0.5)).x;
    gradedSDR.y = tex2D(s_crv, float2(originalHDR.y, 0.5)).y;
    gradedSDR.z = tex2D(s_crv, float2(originalHDR.z, 0.5)).z;

    // Apply Contrast and Bias (CONST_103.x and .y)
    gradedSDR = gradedSDR * CONST_103.x + CONST_103.y;

    // Saturation Math (CONST_103.z)
    float3 lumaWeights = float3(0.2125, 0.7154, 0.0721);
    float gradedLuma = dot(lumaWeights, gradedSDR);
    float3 diff = gradedSDR - gradedLuma;
    gradedSDR = diff * CONST_103.z + gradedLuma;

    // --- HDR LUMINANCE RESTORATION ---
    // Calculate the luminance of the original HDR image
    float originalLuma = dot(lumaWeights, originalHDR);
    
    // Calculate the luminance of our fully graded SDR image
    float finalGradedLuma = dot(lumaWeights, gradedSDR);

    // Scale the graded color by the ratio.
    float3 finalColor = gradedSDR * (originalLuma / max(finalGradedLuma, 0.001));
    finalColor = lerp(originalHDR, finalColor, RENODX_COLOR_GRADE_STRENGTH);

    return float4(finalColor, originalImage.w);
}