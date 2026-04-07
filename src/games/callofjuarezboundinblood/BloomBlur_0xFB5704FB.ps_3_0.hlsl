#include "./shared.h"

sampler2D s_tex : register( s0 );

float4 main(float4 texcoord: TEXCOORD) : COLOR
{
    // Improved Version
  if (RENODX_TONE_MAP_TYPE > 0.f) {
    // center
    float2 center = float2(texcoord.x + texcoord.z, texcoord.y + texcoord.w) * 0.5;

    // Calculate the distance (delta) between the UVs to fake a Texel Size
    // abs() ensures we don't accidentally invert the UVs
    float2 stepsize = float2(abs(texcoord.z - texcoord.x), abs(texcoord.w - texcoord.y)) * (pow(CUSTOM_BLOOM_RADIUS, 2));

    // Sample Center (Weight: 0.25)
    float4 color = tex2D(s_tex, center) * 0.25;

    // Sample the Outer Corners (Weight: 0.0625 each)
    color += tex2D(s_tex, center + float2(-stepsize.x, -stepsize.y)) * 0.0625;
    color += tex2D(s_tex, center + float2( stepsize.x, -stepsize.y)) * 0.0625;
    color += tex2D(s_tex, center + float2(-stepsize.x,  stepsize.y)) * 0.0625;
    color += tex2D(s_tex, center + float2( stepsize.x,  stepsize.y)) * 0.0625;

    // Sample the Outer Edges (Weight: 0.125 each)
    color += tex2D(s_tex, center + float2( 0.0,    -stepsize.y)) * 0.125;
    color += tex2D(s_tex, center + float2( 0.0,     stepsize.y)) * 0.125;
    color += tex2D(s_tex, center + float2(-stepsize.x,  0.0))    * 0.125;
    color += tex2D(s_tex, center + float2( stepsize.x,  0.0))    * 0.125;

    return max(0.f, color);
  } else {
    // Vanilla version
    float4 o;

    float4 r0;
    float4 r1;
    r0 = float4(1, 1, 1, 0) * texcoord.xwwx;
    r0 = tex2Dlod(s_tex, r0);
    r0 = r0 * 0.25;
    r1 = float4(1, 1, 1, 0) * texcoord.xyyx;
    r1 = tex2Dlod(s_tex, r1);
    r0 = r1 * 0.25 + r0;
    r1 = float4(1, 1, 1, 0) * texcoord.zyyx;
    r1 = tex2Dlod(s_tex, r1);
    r0 = r1 * 0.25 + r0;
    r1 = float4(1, 1, 1, 0) * texcoord.zwwx;
    r1 = tex2Dlod(s_tex, r1);
    o = r1 * 0.25 + r0;

    return o;
  }
}