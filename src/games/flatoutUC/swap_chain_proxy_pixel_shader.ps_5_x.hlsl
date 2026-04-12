#include "./shared.h"

Texture2D t0 : register(t0);
SamplerState s0 : register(s0);
float4 main(float4 vpos: SV_POSITION, float2 uv: TEXCOORD0)
    : SV_TARGET {
  float4 output = t0.Sample(s0, uv);
  output.rgb = renodx::color::srgb::DecodeSafe(output.rgb);
  output.rgb = renodx::color::correct::GammaSafe(output.rgb, false, 2.2f);
  return renodx::draw::SwapChainPass(output);
}
