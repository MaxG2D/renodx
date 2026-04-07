#include "./shared.h"

float4 CONST_103 : register( c0 );
float4 GAMMA : register( c1 );
sampler2D s_crv : register( s1 );
sampler2D s_tex : register( s0 );

float4 main(float2 texcoord : TEXCOORD) : COLOR
{
    // Sample original HDR image
    float4 r0 = tex2Dlod(s_tex, float4(texcoord, 0, 0));
    float3 originalHDR = r0.xyz;

    // Sample the 1D Curve (This clamps the data to SDR)
    float3 gradedSDR;
    gradedSDR.x = tex2D(s_crv, float2(r0.x, 0.5)).x;
    gradedSDR.y = tex2D(s_crv, float2(r0.y, 0.5)).y;
    gradedSDR.z = tex2D(s_crv, float2(r0.z, 0.5)).z;

    // Apply Contrast and Bias (CONST_103.x and .y)
    gradedSDR = gradedSDR * CONST_103.x + CONST_103.y;

    // Saturation (CONST_103.z)
    float3 lumaWeights = float3(0.2125, 0.7154, 0.0721);
    float gradedLuma = dot(lumaWeights, gradedSDR);
    float3 diff = gradedSDR - gradedLuma;
    gradedSDR = diff * CONST_103.z + gradedLuma;

    // Gamma Correction (Log2/Exp2)
    gradedSDR = exp2(log2(max(gradedSDR, 0.001)) * GAMMA.y);

    // --- HDR LUMINANCE RESTORATION ---
    // Calculate the luminance of the original HDR image
    float originalLuma = dot(lumaWeights, originalHDR);
    
    // Calculate the luminance of our fully graded SDR image
    float finalGradedLuma = dot(lumaWeights, gradedSDR);

    // Scale the graded color by the ratio.
    float3 finalColor = gradedSDR * (originalLuma / max(finalGradedLuma, 0.001));
    finalColor = lerp(originalHDR, finalColor, RENODX_COLOR_GRADE_STRENGTH);

    return float4(finalColor, r0.w);
}