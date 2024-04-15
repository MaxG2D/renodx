/*
 * Copyright (C) 2023 Carlos Lopez
 * SPDX-License-Identifier: MIT
 */

#define ImTextureID ImU64

#define DEBUG_LEVEL_0

#include <embed/0x61CC29E6.h> // TAA
#include <embed/0x676B8B5D.h> // Tonemapping
#include <embed/0x8024E8B5.h> // Tonemapping
#include <embed/0x80802E60.h> // LUT

#include <deps/imgui/imgui.h>
#include <include/reshade.hpp>

#include "../common/shaderReplaceMod.hpp"
#include "../common/swapChainUpgradeMod.hpp"

extern "C" __declspec(dllexport) const char* NAME = "RenoDX unofficial - Fallout4";
extern "C" __declspec(dllexport) const char* DESCRIPTION = "RenoDX unofficial for Fallout4";

ShaderReplaceMod::CustomShaders customShaders = {
  CustomShaderEntry(0x61CC29E6),
  CustomShaderEntry(0x676B8B5D),
  CustomShaderEntry(0x8024E8B5),
  CustomShaderEntry(0x80802E60)
};

BOOL APIENTRY DllMain(HMODULE hModule, DWORD fdwReason, LPVOID) {
  switch (fdwReason) {
    case DLL_PROCESS_ATTACH:
      if (!reshade::register_addon(hModule)) return FALSE;
      SwapChainUpgradeMod::upgradeResourceViews = false;
      ShaderReplaceMod::forcePipelineCloning = true;
      break;
    case DLL_PROCESS_DETACH:
      reshade::unregister_addon(hModule);
      break;
  }
  SwapChainUpgradeMod::use(fdwReason);
  ShaderReplaceMod::use(fdwReason, &customShaders);

  return TRUE;
}
