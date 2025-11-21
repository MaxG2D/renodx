//
// Optimized & Readable Post-Processing Shader
// Refactored from legacy ASM logic
//

// Textures
sampler2D TextureBase     : register(s0); // s0: Main Render
sampler2D TextureBloom    : register(s1); // s1: Bloom Buffer
sampler2D TextureGrading  : register(s2); // s2: 1D Color Grading LUT
sampler2D TextureVignette : register(s3); // s3: Vignette/Global Weight
sampler2D TextureBleach   : register(s4); // s4: Bleach Bypass Ramp
sampler2D TextureOverlay  : register(s5); // s5: Overlay/Dirt Layer

// Parameters
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
    float4 baseColor    = tex2D(TextureBase, input.uv);
    float4 overlayColor = tex2D(TextureOverlay, input.uv);
    float4 vignette     = tex2D(TextureVignette, float2(LUT_V_COORD, 0.0f));
    float4 bloomColor   = tex2D(TextureBloom, input.uv);

    // FIX: Switched to standard RGB mixing.
    // Previous versions mimicked an ASM quirk that dropped the Blue channel.
    float3 composition = overlayColor.w * baseColor.rgb + overlayColor.rgb;

    // Apply Vignette/Global Weighting
    float3 combinedRGB = composition * vignette.x;

    // 2. Color Grading (LUT Lookup)
    // -----------------------------
    // Transform RGB values to UV coordinates for the LUT
    float3 lutUV = combinedRGB * g_CurveParams.y + LUT_OFFSET;

    // Sample LUT.
    float3 gradedColor;
    gradedColor.r = tex2D(TextureGrading, float2(lutUV.r, LUT_V_COORD)).r;
    gradedColor.g = tex2D(TextureGrading, float2(lutUV.g, LUT_V_COORD)).r;
    gradedColor.b = tex2D(TextureGrading, float2(lutUV.b, LUT_V_COORD)).r;

    // Apply Gamma/Curve Power to the LUT result
    gradedColor = pow(gradedColor, g_CurveParams.x);

    // 3. Add Bloom
    // ------------
    float3 colorWithBloom = (bloomColor.rgb * g_BloomTint.rgb + gradedColor);
    //float3 colorWithBloom = gradedColor;

    // 4. Bleach Bypass & Saturation
    // -----------------------------
    // Pre-Bleach Gamma/Curve
    float3 preBleach = pow(colorWithBloom, g_BleachParams.z);

    // Calculate Luminance
    float luma = dot(preBleach, LUMA_WEIGHTS);

    // Sample Bleach Ramp based on Luma
    float3 bleachSample = tex2D(TextureBleach, float2(luma, LUT_V_COORD)).rgb;

    // Lerp between original and bleach sample (Bleach Mix)
    float3 bleachResult = lerp(preBleach, bleachSample, g_BleachParams.y);

    // 5. Dynamic Contrast / Luma Correction
    // -------------------------------------
    // Standard Contrast Formula: (Value - 0.5) * Contrast + 0.5
    // Logic: ScaleColor = BleachResult * (ContrastLuma / OriginalLuma)
    
    float contrastLuma = saturate((luma - 0.5f) * g_BleachParams.x);
    float contrastScale = max(contrastLuma / (luma + EPSILON), 0.0f); 

    float3 contrastColor = (bleachResult * (contrastScale + 1.0));

    // 6. Final Levels & Post-Curve
    // ----------------------------
    // Post-Contrast Gamma
    float3 postCurve = pow(contrastColor, g_BleachParams.w);

    // Levels Adjustment (Input Range Remapping)
    // (Val - InMin) * Scale + 0.5
    float3 levelsDiff = postCurve - g_Levels.y;
    float3 levelsScale = (levelsDiff >= 0.0f) ? g_Levels.z : g_Levels.x;
    
    float3 finalColor = (levelsDiff * levelsScale + 0.5f);

    return float4(combinedRGB, baseColor.a);
}