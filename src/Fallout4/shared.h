#ifndef SRC_FALLOUT4_SHARED_H_
#define SRC_FALLOUT4_SHARED_H_

// Must be 32bit aligned
// Should be 4x32
struct ShaderInjectData {
  float fxSpecularAmount;
  float fxSunDirectionalAmount;
  float fxSunDiskAmount;
  float fxWaterSpecularAmount;
  float fxWaterSpecularRoughness;
  float fxWaterWavesHeight;
  float fxWaterWavesScale;
};

#ifndef __cplusplus
cbuffer cb11 : register(b11) {
  ShaderInjectData injectedData : packoffset(c0);
}
#endif

#endif  // SRC_FALLOUT4_SHARED_H_
