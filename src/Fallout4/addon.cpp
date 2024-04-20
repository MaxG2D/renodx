/*
 * Copyright (C) 2023 Carlos Lopez
 * SPDX-License-Identifier: MIT
 */

#define ImTextureID ImU64

#define DEBUG_LEVEL_0

#include <embed/0x61CC29E6.h> // TAA - Part 1
#include <embed/0x8CAC3BD9.h> // TAA - Part 2
#include <embed/0x676B8B5D.h> // Tonemapping
#include <embed/0x8024E8B5.h> // Tonemapping
#include <embed/0x80802E60.h> // LUT (YEETED COMPLETELY, TOO BAD!)
#include <embed/0x0E30E611.h> // Specular, SunDirectionalLighting (BROKEN FOR NOW, NOT ALL SHADER VARIANTS REPLACED, TOO BAD!)
#include <embed/0x7FE25E5A.h> // SunDisk (It's very dim in vanilla, can't really be changed with Creation Kit)
//#include <embed/0x2C49CF0C.h> // Removing Gamma Correction from menu item inspect screen - part 1 (NOT NEEDED NOW THAT THE WHOLE UI IS GAMMA CORRECTED!)
//#include <embed/0x58010595.h> // Removing Gamma Correction from menu item inspect screen - part 2 (NOT NEEDED NOW THAT THE WHOLE UI IS GAMMA CORRECTED!)
#include <embed/0xBA5E7BEF.h> // Fix negative colors on on-screen blood effect
//#include <embed/0x3E58E26F.h> // Loading (RGB) menu overlay
//#include <embed/0x55825EE1.h> // ESC (A) menu overlay
#include <embed/0xB74B05F4.h> // Clear before drawing menu overlay, I suspect it causes issues with swapchain upgrades?
#include <embed/0xF9EC8EA4.h> // UI (Added gamma correction, otherwise it looks wrong in HDR)

#include <deps/imgui/imgui.h>
#include <include/reshade.hpp>

#include "../common/UserSettingUtil.hpp"
#include "../common/shaderReplaceMod.hpp"
#include "../common/swapChainUpgradeMod.hpp"
#include "./shared.h"

extern "C" __declspec(dllexport) const char* NAME = "RenoDX unofficial - Fallout4";
extern "C" __declspec(dllexport) const char* DESCRIPTION = "RenoDX unofficial for Fallout4";

ShaderReplaceMod::CustomShaders customShaders = {
  CustomShaderEntry(0x61CC29E6),
  CustomShaderEntry(0x8CAC3BD9),
  CustomShaderEntry(0x676B8B5D),
  CustomShaderEntry(0x8024E8B5),
  CustomShaderEntry(0x80802E60),
  CustomShaderEntry(0x0E30E611),
  CustomShaderEntry(0x7FE25E5A),
  //CustomShaderEntry(0x2C49CF0C),
  //CustomShaderEntry(0x58010595),
  CustomShaderEntry(0xBA5E7BEF),
  //CustomShaderEntry(0x3E58E26F),
  //CustomShaderEntry(0x55825EE1),
  CustomShaderEntry(0xB74B05F4),
  CustomShaderEntry(0xF9EC8EA4)
};

ShaderInjectData shaderInjection;

// clang-format off
UserSettingUtil::UserSettings userSettings = {
    new UserSettingUtil::UserSetting {
    .key = "fxSpecularAmount",
    .binding = &shaderInjection.fxSpecularAmount,
    .defaultValue = 1.f,
    .label = "SpecularAmount",
    .section = "GameHDRValues",
    .max = 100.f,
  },
    new UserSettingUtil::UserSetting {
    .key = "fxSunDirectionalAmount",
    .binding = &shaderInjection.fxSunDirectionalAmount,
    .defaultValue = 1.f,
    .label = "SunDirectionalAmount",
    .section = "GameHDRValues",
    .max = 100.f,
  },
      new UserSettingUtil::UserSetting {
    .key = "fxSunDiskAmount",
    .binding = &shaderInjection.fxSunDiskAmount,
    .defaultValue = 1.f,
    .label = "SunDiskAmount",
    .section = "GameHDRValues",
    .max = 100000.f,
  }
};

// clang-format on

static void onPresetOff() {
  UserSettingUtil::updateUserSetting("fxSpecularAmount", 1.f);
  UserSettingUtil::updateUserSetting("fxSunDirectionalAmount", 1.f);
  UserSettingUtil::updateUserSetting("fxSunDiskAmount", 1.f);
}

BOOL APIENTRY DllMain(HMODULE hModule, DWORD fdwReason, LPVOID) {
  switch (fdwReason) {
    case DLL_PROCESS_ATTACH:
      if (!reshade::register_addon(hModule)) return FALSE;

      ShaderReplaceMod::expectedConstantBufferIndex = 11;
      SwapChainUpgradeMod::upgradeResourceViews = false;
      ShaderReplaceMod::forcePipelineCloning = true;
      
      break;      
    case DLL_PROCESS_DETACH:
      reshade::unregister_addon(hModule);
      break;
  }
  UserSettingUtil::use(fdwReason, &userSettings, &onPresetOff);
  SwapChainUpgradeMod::use(fdwReason);
  ShaderReplaceMod::use(fdwReason, &customShaders, &shaderInjection);

  return TRUE;
}
