float3 ApplyFakeHDRGain(float3 color, float gainScale, float threshold, float saturationBoost)
{
    const float EPSILON = 1e-6;
    const float3 lumaCoeff = float3(0.2126, 0.7152, 0.0722);

    // Original luminance + chroma
    float luminanceInput = dot(color, lumaCoeff);
    float3 chromaInput = color - luminanceInput.xxx;
    float chromaInputMagnitude = max(length(chromaInput), EPSILON);

    // --- 1) Smooth exponential threshold mask ---
    float3 thresholdMask = 1.0 - exp(- (color / max(threshold, EPSILON)));
    thresholdMask = pow(thresholdMask, 1.5);

    // --- 2) Apply gain ---
    float3 gainMasked = color * (1.0 + gainScale * luminanceInput * thresholdMask);

    // New luminance + chroma after gain
    float luminanceGain = dot(gainMasked, lumaCoeff);
    float3 chroma = gainMasked - luminanceGain.xxx;
    float chromaMagnitude = max(length(chroma), EPSILON);

    // --- 3) Apply saturation boost ---
    float3 chromaBoosted = chroma * (1.0 + saturationBoost);

    // --- 4) Procedural saturation preservation ---
    // More gainScale = more suppression of boosted saturation
    float gainInfluence = saturate(gainScale * 1);

    // Ratio of how much saturation we *should* keep
    float saturationRatio = saturate(chromaInputMagnitude / chromaMagnitude);

    // Blend boosted chroma back toward non-boosted chroma
    float saturationBleed = gainInfluence * (1.0 - saturationRatio);

    float3 chromaFinal = lerp(chromaBoosted, chroma, saturationBleed);

    // --- 5) Recombine ---
    float3 output = luminanceGain.xxx + chromaFinal;

    // --- 6) Soft HDR compression ---
    float maxValueGain = max(max(output.r, output.g), output.b);
    float headroom = max(1.0, maxValueGain * 5.0);
    float compressMul = 1.0 / (1.0 + maxValueGain / (headroom + EPSILON));
    output *= compressMul;

    return max(output, 0.0);
}
