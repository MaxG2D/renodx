/*
 * Copyright (C) 2023 Carlos Lopez
 * SPDX-License-Identifier: MIT
 */

#define ImTextureID ImU64

#define DEBUG_LEVEL_0

#include <embed/0x61CC29E6.h> // TAA (SLIGHTLY BROKEN BY UPGRADE, TOO BAD!)
#include <embed/0x676B8B5D.h> // Tonemapping
#include <embed/0x8024E8B5.h> // Tonemapping
#include <embed/0x80802E60.h> // LUT (YEETED COMPLETELY, TOO BAD!)
#include <embed/0x0E30E611.h> // SunSpecular, SunDirectionalLighting (BROKEN FOR NOW, NOT ALL SHADER VARIANTS REPLACED, TOO BAD!)
#include <embed/0x516537DC.h> // SunDisk (it's very dim in vanilla, can't really be changed with Creation Kit, BROKEN FOR NOW, TOO BAD!)

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
  CustomShaderEntry(0x676B8B5D),
  CustomShaderEntry(0x8024E8B5),
  CustomShaderEntry(0x80802E60),
  CustomShaderEntry(0x0E30E611),
  CustomShaderEntry(0x516537DC)
};

ShaderInjectData shaderInjection;

// clang-format off
UserSettingUtil::UserSettings userSettings = {
    new UserSettingUtil::UserSetting {
    .key = "fxSunSpecularAmount",
    .binding = &shaderInjection.fxSunSpecularAmount,
    .defaultValue = 1.f,
    .label = "SunSpecularAmount",
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
    .max = 100.f,
  }
};

// clang-format on

static void onPresetOff() {
  UserSettingUtil::updateUserSetting("fxSunSpecularAmount", 1.f);
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
