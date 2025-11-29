#include "./shared.h"

// Radial Blur
float4 g_vRadialBlurParams : register( c117 );
sampler2D s0 : register( s0 );
sampler2D s1 : register( s1 );

// Depth Resources taken from different shader
sampler2D SceneDepthMap : register( s12 );
float4 g_PS_depthBufferScale : register( c52 ); 

static const int TOTAL_SAMPLES = 32;
static const float INV_SAMPLE_COUNT = 1.0f / (float)(TOTAL_SAMPLES); 
static const float HALF_FLOAT = 0.5;

static const float BLUR_MIN_RADIUS = 0.3f; 
static const float BLUR_MAX_RADIUS = 0.7f;
static const float2 CENTER_OFFSET = float2(0.0, 0.1);
static const float GAMMA = 2.2f;
static const float INV_GAMMA = 1.0f / 2.2f;
static const float3 LUMINANCE_VECTOR = float3(0.2126f, 0.7152f, 0.0722f);
static const float DEPTH_FALLOFF_START = 0.0f; 
static const float DEPTH_FALLOFF_END = 150.0f; 

// --- STABILIZATION CONSTANTS ---
static const float MAX_VELOCITY_SCALE = 1.5f;   // Limit the input velocity magnitude
static const float MAX_STREAK_LENGTH = 0.10f;  // Max streak length as a fraction of screen (15%)
static const float MAX_DEPTH_DIFF = 0.003f;    // Max raw depth (0..1) difference allowed between pixel and sample
// ------------------------------

float LinearizeDepth(float depthSample)
{
    float linearDepth = depthSample * g_PS_depthBufferScale.x + g_PS_depthBufferScale.y;
    return linearDepth;
}

float2 CalculateMaskWarpUV(float4 centerToUVDirection4, float4 params)
{
    float4 maskDenominator = float4(0, 0, 0, 0);
    float4 signMapping = float4(0, 0, 0, 0);
    maskDenominator.xy = (-centerToUVDirection4.zw >= 0) ? 0 : 1;
    signMapping = (centerToUVDirection4 >= 0) ? float4(1, 1, 0, 0) : float4(0, 0, -1, -1);
    maskDenominator.zw = centerToUVDirection4.xy * HALF_FLOAT;
    maskDenominator.xy = maskDenominator.xy + signMapping.zw;
    maskDenominator.xy = maskDenominator.xy * -params.xy + signMapping.xy;
    float2 invR0 = float2(1.0 / maskDenominator.x, 1.0 / maskDenominator.y);
    return (maskDenominator.zw * invR0.xy) + HALF_FLOAT;
}

float4 main(float2 texcoord : TEXCOORD) : COLOR
{
    float4 finalOutput;

    // Depth Calculation
    float rawDepth = tex2D(SceneDepthMap, texcoord).x; 
    float viewSpaceDepth = LinearizeDepth(rawDepth); 
    static const float RAW_FADE_START = 0.8f; 
    static const float RAW_FADE_END = 1.0f;
    float depthFactor = 1.0f - smoothstep(RAW_FADE_START, RAW_FADE_END, rawDepth);
    float smoothDepthFade = smoothstep(DEPTH_FALLOFF_END, DEPTH_FALLOFF_START, viewSpaceDepth);
    depthFactor *= smoothDepthFade; 

    // UV Setup
    float2 blurCenter = g_vRadialBlurParams.xy + CENTER_OFFSET; 
    float4 centerToUVDirection = texcoord.xyxy - blurCenter.xyxy;
    float velocityMagnitude = min(g_vRadialBlurParams.z, MAX_VELOCITY_SCALE);
    float distFromCenter = length(pow(centerToUVDirection.xy, 1.0f));
    float blurIntensity = smoothstep(BLUR_MIN_RADIUS, BLUR_MAX_RADIUS, distFromCenter); 
    float scaledBlurIntensity = blurIntensity * depthFactor;
    float2 fullStepVector = centerToUVDirection.xy * (velocityMagnitude * 4.0f) * scaledBlurIntensity;
    float stepLength = length(fullStepVector);
    fullStepVector = fullStepVector / max(stepLength, 0.0001f) * min(stepLength, MAX_STREAK_LENGTH);

    float3 accumulatedColor = float3(0,0,0);
    float totalWeight = 0.0;

    // Accumulation Loop
    for (int i = 0; i < TOTAL_SAMPLES; i++)
    {
        float t = float(i) * INV_SAMPLE_COUNT; 
        float stepMult = t - 0.5f;
        float2 sampleCoords = texcoord.xy + (fullStepVector * stepMult);
        
        // Sample & Depth Check
        float3 sampleColor = tex2D(s0, sampleCoords).xyz;
        float sampleRawDepth = tex2D(SceneDepthMap, sampleCoords).x;
        float depthDiff = abs(rawDepth - sampleRawDepth); 
        float depthAttenuation = smoothstep(MAX_DEPTH_DIFF, 0.0f, depthDiff);
        float3 linearColor = pow(sampleColor, GAMMA);
        float luma = dot(linearColor, LUMINANCE_VECTOR);
        float hdrWeight = 1.0 + luma; 
        float distWeight = saturate(1.0 - abs(stepMult * 2.0)); 
        float finalSampleWeight = hdrWeight * distWeight * depthAttenuation;

        accumulatedColor += linearColor * finalSampleWeight;
        totalWeight += finalSampleWeight;
    }
    
    float3 finalLinearColor = accumulatedColor / max(totalWeight, 0.0001f);
    finalOutput.xyz = pow(finalLinearColor, INV_GAMMA);

    // Alpha Mask Blending (using max to combine masks cleanly)
    float2 maskUV = CalculateMaskWarpUV(centerToUVDirection, g_vRadialBlurParams);
    float rawMaskAlpha = tex2D(s1, maskUV).w;
    if (velocityMagnitude > 0.01f)
    {
        finalOutput.w = scaledBlurIntensity;
    }
    else
    {
        finalOutput.w = rawMaskAlpha;
    }

    return finalOutput;
}