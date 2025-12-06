// TV Render Target shader with CRT overlay

sampler2D Tex0               : register(s0);
float4 g_PS_eyePosWorld      : register(c17);   // uses .y
float4 g_PS_fogColor         : register(c44);
float  g_PS_fxTime           : register(c63);   // scalar

struct PS_IN
{
    float3 uv_fogfactor : TEXCOORD0;  // xy = UV, z = fog factor
    float2 wave_src     : TEXCOORD1;  // ASM uses .y
};

float4 main(PS_IN i) : COLOR
{
    const float4 c0 = float4(0.75f, 1.0f, 0.0f, 0.0f);
    const float4 c1 = float4(0.699999988f, 7.13000011f, 3.0f, 0.5f);
    const float4 c2 = float4(6.28318548f, -3.14159274f, 0.25f, 0.75f);

    float2 uv        = i.uv_fogfactor.xy;
    float  fogFactor = i.uv_fogfactor.z;
    float  waveY     = i.wave_src.y;

    //
    // Phase computation (matches ASM exactly)
    //
    float phase = g_PS_eyePosWorld.y + waveY;   // add
    phase *= c1.y;                               // * 7.13
    phase = g_PS_fxTime * c1.z + phase;          // + time * 3
    phase = frac(phase);
    phase = frac(phase + c1.w);                  // +0.5 then frac
    phase = phase * c2.x + c2.y;                 // *2π - π

    //
    // Brightness multiplier: sin(phase) * 0.25 + 0.75
    //
    float brightness = sin(phase) * c2.z + c2.w;

    //
    // Texture sample + dimming
    //
    float4 texColor  = tex2D(Tex0, uv);
    // float4 dimmed    = saturate(texColor * c1.x);      // *0.7
    float4 dimmed = (texColor * c1.x);
    float4 modulated = dimmed * brightness;            // r0

    //
    // Two fog–mix components (matches r1 and r0.rgb logic)
    //
    float3 fogInfluence = modulated.rgb * float3(c0.x, c0.y, c0.x);
    float3 fogOffset    = g_PS_fogColor.rgb - (modulated.rgb * float3(c0.x, c0.y, c0.x));

    //
    // Final fog blend
    //
    float3 outRGB = max(0.f, fogFactor * fogOffset + fogInfluence);
    float  outA   = modulated.a;

    return float4(outRGB, outA);
}
