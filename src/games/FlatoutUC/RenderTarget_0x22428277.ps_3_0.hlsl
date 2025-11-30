// Render Targer CRT TV Shader

sampler2D NormalMap0       : register(s5);
sampler2D ShadowMapArray   : register(s10);
sampler2D Tex0             : register(s0);

float4 g_PS_visibilityFactors    : register(c0);
float4 g_PS_externalLight        : register(c1);
float4 g_PS_viewDirWorld         : register(c16);
float4 g_PS_eyePosWorld          : register(c17);
float4 g_PS_shadowMapMaxZ        : register(c19);
float4 g_PS_shadowMapScaleDepths : register(c20); // .xyzw used
float4 g_PS_shadowMapOffsets     : register(c24); // .xyzw used
float4 g_PS_ambientBlack         : register(c32);
float4 g_PS_diffuseLightColor    : register(c37);
float4 g_PS_fogColor             : register(c44);
float  g_PS_fxTime               : register(c63);

// ASM-defined constants (exact)
static const float4 C2 = float4(-0.0f, -1.0f, -2.0f, -3.0f);
static const float4 C3 = float4(0.699999988f, 7.13000011f, 3.0f, 0.5f);
static const float4 C4 = float4(6.28318548f, -3.14159274f, 0.25f, 0.75f);
static const float4 C5 = float4(0.75f, 1.0f, 0.0f, 0.5f);
static const float4 C6 = float4(-0.899999976f, -1.10000002f, -2.0999999f, -7.9999998e-005f);
static const float4 C7 = float4(0.675000012f, 0.899999976f, 0.100000001f, 0.0f);
static const float4 C8 = float4(-0.000178710936f, -0.000666992215f, 0.000666992215f, 0.000178710936f);

struct PS_IN
{
    float4 texcoord  : TEXCOORD0; // v0.xy = UV ; v0.z = fog factor ; v0.w used in cmp
    float3 texcoord1 : TEXCOORD1; // v1
    float3 texcoord2 : TEXCOORD2; // v2 (wave & view dot)
    float3 texcoord3 : TEXCOORD3; // v3 (shadow coords)
    float3 texcoord4 : TEXCOORD4; // v4 (ambient param)
};

float4 main(PS_IN i) : COLOR
{
    // -------------------------
    // 0) Sample base albedo and dim it (ASM: texld_pp r0; mul_sat r0, r0, c3.x)
    // -------------------------
    float4 baseSample = tex2D(Tex0, i.texcoord.xy);              // r0
	//baseSample = saturate(baseSample * C3.x);                    // mul_sat by 0.7
	baseSample = (baseSample * C3.x);

    // -------------------------
    // 1) Build brightness multiplier from sine wave (ASM sequence preserved)
    //    r1.w = ( (frac( ( (eyeY + v2.y) * 7.13 + time*3 ) ) + 0.5 ) frac ) * 2π - π ; sin -> remap
    // -------------------------
    float phase = g_PS_eyePosWorld.y + i.texcoord2.y;           // add c17.y + v2.y
    phase *= C3.y;                                              // * 7.13
    phase = g_PS_fxTime * C3.z + phase;                         // + time*3 (mad)
    phase = frac(phase);                                        // frc
    phase = frac(phase + C3.w);                                 // +0.5 then frc
    phase = phase * C4.x + C4.y;                                // *2π + (-π)
    float sineVal = sin(phase);                                 // sin
    float brightness = sineVal * C4.z + C4.w;                   // sin*0.25 + 0.75

    // apply brightness multiplier to the dimmed albedo
    float4 modAlbedo = baseSample * brightness;                 // r0 *= r1.w

    // -------------------------
    // 2) Precompute texture-influence term (ASM: r2 = r0 * c5.xyxw)
    // -------------------------
    float3 texInfluence = modAlbedo.rgb * float3(C5.x, C5.y, C5.x); // r2.xyz

    // -------------------------
    // 3) Normal map unpack & helper computations (ASM: sample r3, transform, rsq, rcp)
    // -------------------------
    float4 nm = tex2D(NormalMap0, i.texcoord.xy);               // r3
    float2 nm_xy = float2(nm.w, nm.y) + (-C3.w);
    nm_xy = nm_xy + nm_xy;                                      // *2
    float tmpVal = 1.0f + (nm_xy.x * -nm_xy.x) + (nm_xy.y * -nm_xy.y);
    float invSqrt = (tmpVal > 0.0f) ? (1.0f / sqrt(tmpVal)) : 0.0f; // safe rsq
    float r3_z = (invSqrt != 0.0f) ? (1.0f / invSqrt) : 0.0f;
    float r1_w_cmp = ((-i.texcoord.w) >= 0.0f) ? C5.z : C5.y;
    float3 normalized_v1 = normalize(i.texcoord1);
    float r1_x = dot(float3(nm_xy.x, nm_xy.y, r3_z), normalized_v1);
    float r2_w = max(r1_x, C5.z);
    float r1_x_after = r1_w_cmp * r2_w;

    // -------------------------
    // 4) Compute view-dot / shadow test pre-conditions (ASM lines 33..37)
    // -------------------------
    float viewDot = dot(i.texcoord2, g_PS_viewDirWorld.xyz);   // r1.y
    float r1_z = -viewDot - g_PS_shadowMapMaxZ.w;              // add -r1.y - c19.w
    r1_z = (r1_z >= 0.0f) ? C5.z : C5.y;                       // cmp -> 0 or 1
    float r1_w_after = ((-r1_x_after) >= 0.0f) ? C5.z : C5.y;  // cmp -> 0 or 1
    r1_z = r1_z * r1_w_after;                                  // mul

    // -------------------------
    // 5) Shadow cascade selection & sampling (preserve ASM tests and order)
    //    We express cascade selection semantically (Style 2), but keep behavior identical.
    // -------------------------
    float visibilityFactor = 0.0f;
    if (r1_z != -r1_z) // ASM: if_ne r1.z, -r1.z (preserve branch)
    {
        float3 testVals;
        testVals.x = (-viewDot) - g_PS_shadowMapMaxZ.x;
        testVals.y = (-viewDot) - g_PS_shadowMapMaxZ.y;
        testVals.z = (-viewDot) - g_PS_shadowMapMaxZ.z;

        float testX = (testVals.x >= 0.0f) ? C5.y : C5.z;
        float testY = (testVals.y >= 0.0f) ? C5.y : C5.z;
        float testW = (testVals.z >= 0.0f) ? C5.y : C5.z;

        // r1.z := sum of tests (how many cascades match)
        float cascadeCount = testX + testY + testW;
        // r4 = cascadeCount + C2 (vector). From that, ASM used chained cmp to pick scales/offsets
        float4 cascadeIndexVec = cascadeCount + C2; // r4
        // Determine chosen scale & offset (start with zeros)
        float2 chosenScale = float2(0.0f, 0.0f);
        float2 chosenOffset = float2(0.0f, 0.0f);
        // Cascade: check r4.x/y/z/w in order, fallback behavior replicates ASM cascading writes.
        // If r4.x == 0 -> pick c20 (scale) and c24 (offset)
        if (abs(cascadeIndexVec.x) == 0.0f)
        {
            chosenScale = g_PS_shadowMapScaleDepths.xy;
            chosenOffset = g_PS_shadowMapOffsets.xy;
        }
        // Else if r4.y == 0 -> pick c21
        else if (abs(cascadeIndexVec.y) == 0.0f)
        {
            chosenScale = float2(g_PS_shadowMapScaleDepths.y, chosenScale.y);
            chosenOffset = float2(g_PS_shadowMapOffsets.y, chosenOffset.y);
        }
        // Else if r4.z == 0 -> pick c22
        else if (abs(cascadeIndexVec.z) == 0.0f)
        {
            chosenScale = float2(g_PS_shadowMapScaleDepths.z, chosenScale.y);
            chosenOffset = float2(g_PS_shadowMapOffsets.z, chosenOffset.y);
        }
        // Else if r4.w == 0 -> pick c23
        else if (abs(cascadeIndexVec.w) == 0.0f)
        {
            chosenScale = float2(g_PS_shadowMapScaleDepths.w, chosenScale.y);
            chosenOffset = float2(g_PS_shadowMapOffsets.w, chosenOffset.y);
        }
        // If none matched, chosenScale remains zero (same as ASM falling back to r5.z = 0)
        float2 sampleBase = i.texcoord3.xy * chosenScale + chosenOffset;
        float2 sampleBaseHalf = sampleBase * C3.w;
        float3 r5xyz = cascadeCount + float3(C6.x, C6.y, C6.z);
        float4 r6 = float4(sampleBase.x * 0.5f, sampleBase.y * 0.5f, sampleBase.x * 0.5f, sampleBase.y * 0.5f)
                   + float4(0.5f, 0.0f, 0.0f, 0.5f);
        float2 baseCoordsHalf = sampleBase * 0.5f + 0.5f;

        // ASM's cmp chain picks final coords depending on signs of r5 components.
        // Emulate final result choosing the same "last applied" semantics:
        float2 finalCoords;
        if (r5xyz.x >= 0.0f) finalCoords = baseCoordsHalf;
        else finalCoords = sampleBaseHalf; // fallback to r4.xy

        // Build four small offsets around finalCoords using C8
        float2 sample0 = finalCoords + float2(C8.x, C8.y);
        float2 sample1 = finalCoords + float2(C8.z, C8.x);
        float2 sample2 = finalCoords + float2(C8.y, C8.w);
        float2 sample3 = finalCoords + float2(C8.w, C8.z);
        // Make tex2Dlod coords (z,w = 0), then sample shadow map LODs
        float4 tc0 = float4(sample0.x, sample0.y, 0.0f, 0.0f);
        float4 tc1 = float4(sample1.x, sample1.y, 0.0f, 0.0f);
        float4 tc2 = float4(sample2.x, sample2.y, 0.0f, 0.0f);
        float4 tc3 = float4(sample3.x, sample3.y, 0.0f, 0.0f);
        float4 s0 = tex2Dlod(ShadowMapArray, tc0);
        float4 s1 = tex2Dlod(ShadowMapArray, tc1);
        float4 s2 = tex2Dlod(ShadowMapArray, tc2);
        float4 s3 = tex2Dlod(ShadowMapArray, tc3);
        // r1.z = small_bias + i.texcoord3.z  (ASM used C6.w + v3.z)
        float small_bias = C6.w + i.texcoord3.z;
        float4 r4vals = float4(0.0f, s1.x, s2.x, s3.x);
        r4vals = r4vals + (-small_bias);
        // cmp r4 -> (r4 >= 0) ? 1 : 0 for each component
        r4vals.x = (r4vals.x >= 0.0f) ? C5.y : C5.z;
        r4vals.y = (r4vals.y >= 0.0f) ? C5.y : C5.z;
        r4vals.z = (r4vals.z >= 0.0f) ? C5.y : C5.z;
        r4vals.w = (r4vals.w >= 0.0f) ? C5.y : C5.z;
        float r1z_final = dot(r4vals, float4(C4.z, C4.z, C4.z, C4.z));
        float invMaxZ = (g_PS_shadowMapMaxZ.w != 0.0f) ? (1.0f / g_PS_shadowMapMaxZ.w) : 0.0f;
        float r1y_post = saturate(-viewDot * invMaxZ);
        visibilityFactor = lerp(g_PS_visibilityFactors.x, r1z_final, r1y_post);
    }
    else
    {
        visibilityFactor = g_PS_visibilityFactors.x;
    }

    // -------------------------
    // 6) Lighting accumulation (ASM lines 83..90)
    // -------------------------
    float3 ambientTerm = float3(i.texcoord4.x, i.texcoord4.x, i.texcoord4.x) * r3_z
                         + float3(g_PS_ambientBlack.x, g_PS_ambientBlack.x, g_PS_ambientBlack.x);
    float r2w_post = r1_x * visibilityFactor;
    // (add diffuse contribution)
    float3 diffuseAcc = r2w_post * float3(g_PS_diffuseLightColor.x, g_PS_diffuseLightColor.x, g_PS_diffuseLightColor.x)
                        + ambientTerm;
    float3 lit = r1_x * g_PS_externalLight.xyz + diffuseAcc;
    // r2.xyz was earlier texInfluence
    float3 r2_xyz_squared = texInfluence * texInfluence;
    lit *= r2_xyz_squared;
    // color scaling of modAlbedo
    float3 scaledAlbedo = modAlbedo.rgb * float3(C7.x, C7.y, C7.x);
    // mix lighting with albedo
    scaledAlbedo = lit * C7.z + scaledAlbedo;

    // fog rem
    float3 fogRem = -scaledAlbedo + g_PS_fogColor.xyz;
    float3 outRGB = i.texcoord.z * fogRem + scaledAlbedo;
    float outAlpha = modAlbedo.a;

    return float4(outRGB, outAlpha);
}
