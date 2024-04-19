/*
 * Copyright (C) 2023 Carlos Lopez
 * SPDX-License-Identifier: MIT
 */

#define ImTextureID ImU64

#include <Windows.h>
#include <array>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <memory>
#include <random>
#include <shared_mutex>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include <deps/imgui/imgui.h>
#include <include/reshade.hpp>

#include <crc32_hash.hpp>
#include "../common/format.hpp"

extern "C" __declspec(dllexport) const char* NAME = "RenoDX - DevKit";
extern "C" __declspec(dllexport) const char* DESCRIPTION = "RenoDX DevKit Module";

struct CachedPipeline {
  reshade::api::pipeline pipeline;
  reshade::api::device* device;
  reshade::api::pipeline_layout layout;
  reshade::api::pipeline_subobject* subobjectsCache;
  uint32_t subobjectCount;
  bool cloned;
  reshade::api::pipeline pipelineClone;
  uint32_t shaderHash;
};

struct CachedShader {
  void* data = nullptr;
  size_t size = 0;
  int32_t index = -1;
  std::string source = "";
};

std::shared_mutex s_mutex;

std::unordered_set<uint64_t> computeShaderLayouts;
std::unordered_set<uint64_t> backBuffers;

std::unordered_map<uint64_t, CachedPipeline*> pipelineCacheByPipelineHandle;
std::unordered_map<uint32_t, CachedPipeline*> pipelineCacheByShaderHash;
std::unordered_map<uint32_t, CachedShader*> shaderCache;

std::unordered_map<uint64_t, reshade::api::pipeline> pipelineCloneMap;

std::vector<uint32_t> traceHashes;

static bool traceScheduled = false;
static bool traceRunning = false;
static bool needsLiveReload = false;
static bool listUnique = false;
static uint32_t shaderCacheCount = 0;
static uint32_t shaderCacheSize = 0;
static uint32_t traceCount = 0;
static uint32_t presentCount = 0;

static const uint32_t MAX_PRESENT_COUNT = 300 * 60;

std::filesystem::path getShaderPath() {
  wchar_t file_prefix[MAX_PATH] = L"";
  GetModuleFileNameW(nullptr, file_prefix, ARRAYSIZE(file_prefix));

  std::filesystem::path dump_path = file_prefix;
  dump_path = dump_path.parent_path();
  dump_path /= ".\\renodx-dev";
  return dump_path;
}

static void loadLiveShaders() {
  const std::unique_lock<std::shared_mutex> lock(s_mutex);
  reshade::log_message(reshade::log_level::debug, "loadLiveShader()");

  // Clear all shaders
  for (auto pair : pipelineCacheByPipelineHandle) {
    auto cachedPipeline = pair.second;
    if (!cachedPipeline->cloned) continue;
    cachedPipeline->device->destroy_pipeline(cachedPipeline->pipelineClone);
    cachedPipeline->cloned = false;
  }

  auto directory = getShaderPath();
  directory /= ".\\live";

  if (std::filesystem::exists(directory) == false) {
    std::stringstream s;
    s << "loadLiveShaders(Directory not found: "
      << directory.string()
      << ")";
    reshade::log_message(reshade::log_level::warning, s.str().c_str());
    return;
  }

  for (const auto &entry : std::filesystem::directory_iterator(directory)) {
    if (!entry.is_regular_file()) {
      reshade::log_message(reshade::log_level::warning, "loadLiveShaders(not a regular file)");
      continue;
    }
    auto entryPath = entry.path();
    if (!entryPath.has_extension()) {
      std::stringstream s;
      s << "loadLiveShaders(Missing extension: "
        << entryPath.string()
        << ")";
      reshade::log_message(reshade::log_level::warning, s.str().c_str());
      continue;
    }
    if (entryPath.extension().compare(".cso") != 0) {
      std::stringstream s;
      s << "loadLiveShaders(Skipping file: "
        << entryPath.string()
        << ")";
      reshade::log_message(reshade::log_level::warning, s.str().c_str());
      continue;
    }

    auto filename = entryPath.filename();
    auto filename_string = filename.string();
    if (filename_string.size() != 14) {
      std::stringstream s;
      s << "loadLiveShaders(Filename length not 14: "
        << filename_string
        << ")";
      reshade::log_message(reshade::log_level::warning, s.str().c_str());
      continue;
    }
    uint32_t hash = std::stoi(filename_string.substr(2, 8), nullptr, 16);

    auto pair = pipelineCacheByShaderHash.find(hash);
    if (pair == pipelineCacheByShaderHash.end()) {
      std::stringstream s;
      s << "loadLiveShaders(Unknown hash: 0x"
        << std::hex << hash << std::dec
        << ")";
      reshade::log_message(reshade::log_level::warning, s.str().c_str());
      continue;
    }
    CachedPipeline* cachedPipeline = pair->second;

    reshade::log_message(reshade::log_level::debug, "Reading file...");
    std::ifstream file(entryPath, std::ios::binary);
    file.seekg(0, std::ios::end);
    size_t code_size = file.tellg();
    char* code = reinterpret_cast<char*>(malloc((code_size + 1) * sizeof(char)));
    file.seekg(0, std::ios::beg).read(code, code_size);
    code[code_size] = NULL;

    {
      std::stringstream s;
      s << "loadLiveShaders(Read "
        << code_size << " bytes "
        << " from " << entryPath.string()
        << ")";
      reshade::log_message(reshade::log_level::debug, s.str().c_str());
    }

    // DX12 can use PSO objects that need to be cloned

    uint32_t subobjectCount = cachedPipeline->subobjectCount;
    reshade::api::pipeline_subobject* subobjects = cachedPipeline->subobjectsCache;
    reshade::api::pipeline_subobject* newSubobjects = new reshade::api::pipeline_subobject[subobjectCount];
    memcpy(newSubobjects, cachedPipeline->subobjectsCache, sizeof(reshade::api::pipeline_subobject) * subobjectCount);

    {
      std::stringstream s;
      s << "loadLiveShaders(Cloning pipeline "
        << reinterpret_cast<void*>(cachedPipeline->pipeline.handle)
        << " with " << subobjectCount << " object(s)"
        << ")";
      reshade::log_message(reshade::log_level::debug, s.str().c_str());
    }
    reshade::log_message(reshade::log_level::debug, "Iterating pipeline...");

    bool needsClone = false;
    bool foundComputeShader = false;
    bool foundInjection = false;
    for (uint32_t i = 0; i < subobjectCount; ++i) {
      reshade::log_message(reshade::log_level::debug, "Checking subobject...");
      const auto subobject = subobjects[i];
      switch (subobject.type) {
        case reshade::api::pipeline_subobject_type::compute_shader:
        case reshade::api::pipeline_subobject_type::pixel_shader:
          break;
        default:
          continue;
      }
      const reshade::api::shader_desc desc = *static_cast<const reshade::api::shader_desc*>(subobject.data);

      // if (desc.code_size == 0) {
      //   reshade::log_message(reshade::log_level::warning, "Code size 0");
      //   continue;
      // }

      // reshade::log_message(reshade::log_level::debug, "Computing hash...");
      // Pipeline has a pixel shader with code. Hash code and check
      // auto shader_hash = compute_crc32(static_cast<const uint8_t*>(desc.code), desc.code_size);
      // if (hash != shader_hash) {
      //   reshade::log_message(reshade::log_level::warning, "");
      //   continue;
      // }

      auto cloneSubject = &newSubobjects[i];

      auto newDesc = static_cast<reshade::api::shader_desc*>(cloneSubject->data);

      newDesc->code = code;
      newDesc->code_size = code_size;

      auto new_hash = compute_crc32(static_cast<const uint8_t*>(newDesc->code), newDesc->code_size);

      std::stringstream s;
      s << "loadLiveShaders(Injected pipeline data"
        << " with 0x" << std::hex << new_hash << std::dec
        << " (" << code_size << " bytes)"
        << ")";
      reshade::log_message(reshade::log_level::debug, s.str().c_str());
    }

    {
      std::stringstream s;
      s << "Creating pipeline clone ("
        << "hash: 0x" << std::hex << hash << std::dec
        << ", layout: " << reinterpret_cast<void*>(cachedPipeline->layout.handle)
        << ", subobjectcount: " << subobjectCount
        << ")";
      reshade::log_message(reshade::log_level::debug, s.str().c_str());
    }

    reshade::api::pipeline pipelineClone;
    bool builtPipelineOK = cachedPipeline->device->create_pipeline(
      cachedPipeline->layout,
      subobjectCount,
      &newSubobjects[0],
      &pipelineClone
    );
    if (builtPipelineOK) {
      pipelineCloneMap.emplace(cachedPipeline->pipeline.handle, pipelineClone);
      cachedPipeline->pipelineClone = pipelineClone;
      cachedPipeline->cloned = true;
    }
    // free(code);
    std::stringstream s;
    s << "loadLiveShaders(cloned "
      << reinterpret_cast<void*>(cachedPipeline->pipeline.handle)
      << " => " << reinterpret_cast<void*>(pipelineClone.handle)
      << ", layout: " << reinterpret_cast<void*>(cachedPipeline->layout.handle)
      << ", size: " << subobjectCount
      << ", " << (builtPipelineOK ? "OK" : "FAILED!")
      << ")";
    reshade::log_message(builtPipelineOK ? reshade::log_level::info : reshade::log_level::error, s.str().c_str());
  }
}

static void logLayout(
  const uint32_t paramCount,
  const reshade::api::pipeline_layout_param* params,
  const reshade::api::pipeline_layout layout
) {
  for (uint32_t paramIndex = 0; paramIndex < paramCount; ++paramIndex) {
    auto param = params[paramIndex];
    if (param.type == reshade::api::pipeline_layout_param_type::descriptor_table) {
      for (uint32_t rangeIndex = 0; rangeIndex < param.descriptor_table.count; ++rangeIndex) {
        auto range = param.descriptor_table.ranges[rangeIndex];
        std::stringstream s;
        s << "logPipelineLayout(";
        s << reinterpret_cast<void*>(layout.handle);
        s << " | TBL";
        s << " | " << reinterpret_cast<void*>(&param.descriptor_table.ranges);
        s << " | ";
        switch (range.type) {
          case reshade::api::descriptor_type::sampler:
            s << "SMP";
            break;
          case reshade::api::descriptor_type::sampler_with_resource_view:
            s << "SRV";
            break;
          case reshade::api::descriptor_type::shader_resource_view:
            s << "SRV2";
            break;
          case reshade::api::descriptor_type::unordered_access_view:
            s << "UAV";
            break;
          case reshade::api::descriptor_type::constant_buffer:
            s << "CBV";
            break;
          case reshade::api::descriptor_type::shader_storage_buffer:
            s << "SSB";
            break;
          case reshade::api::descriptor_type::acceleration_structure:
            s << "ACC";
            break;
          default:
            s << "???";
        }

        s << " | " << range.array_size
          << " | " << range.binding
          << " | " << range.count
          << " | " << range.dx_register_index
          << " | " << range.dx_register_space
          << " | " << to_string(range.visibility)
          << ")"
          << " [" << rangeIndex << "/" << param.descriptor_table.count << "]"
          << " [" << paramIndex << "/" << paramCount << "]";
        reshade::log_message(reshade::log_level::info, s.str().c_str());
      }
    } else if (param.type == reshade::api::pipeline_layout_param_type::push_constants) {
      std::stringstream s;
      s << "logPipelineLayout(";
      s << reinterpret_cast<void*>(layout.handle);
      s << " | PC"
        << " | " << param.push_constants.binding
        << " | " << param.push_constants.count
        << " | " << param.push_constants.dx_register_index
        << " | " << param.push_constants.dx_register_space
        << " | " << to_string(param.push_constants.visibility)
        << ")"
        << " [" << paramIndex << "/" << paramCount << "]";
      reshade::log_message(reshade::log_level::info, s.str().c_str());
    } else if (param.type == reshade::api::pipeline_layout_param_type::push_descriptors) {
      std::stringstream s;
      s << "logPipelineLayout(";
      s << reinterpret_cast<void*>(layout.handle);
      s << " | PD"
        << " | " << param.push_descriptors.array_size
        << " | " << param.push_descriptors.binding
        << " | " << param.push_descriptors.count
        << " | " << param.push_descriptors.dx_register_index
        << " | " << param.push_descriptors.dx_register_space
        << " | " << to_string(param.push_descriptors.type)
        << " | " << to_string(param.push_descriptors.visibility)
        << ")"
        << " [" << paramIndex << "/" << paramCount << "]";
      reshade::log_message(reshade::log_level::info, s.str().c_str());
    } else if (param.type == reshade::api::pipeline_layout_param_type::push_descriptors_with_ranges) {
      std::stringstream s;
      s << "logPipelineLayout("
        << reinterpret_cast<void*>(layout.handle)
        << " | PDR?? | "
        << ")"
        << " [" << paramIndex << "/" << paramCount << "]";
      reshade::log_message(reshade::log_level::info, s.str().c_str());
    } else {
      std::stringstream s;
      s << "logPipelineLayout("
        << reinterpret_cast<void*>(layout.handle)
        << " | ???"
        << " | " << to_string(param.type)
        << ")"
        << " [" << paramIndex << "/" << paramCount << "]";
      reshade::log_message(reshade::log_level::info, s.str().c_str());
    }
  }
}

static void on_init_swapchain(reshade::api::swapchain* swapchain) {
  const size_t backBufferCount = swapchain->get_back_buffer_count();

  for (uint32_t index = 0; index < backBufferCount; index++) {
    auto buffer = swapchain->get_back_buffer(index);
    backBuffers.emplace(buffer.handle);

    std::stringstream s;
    s << "init_swapchain("
      << "buffer:" << reinterpret_cast<void*>(buffer.handle)
      << ")";
    reshade::log_message(reshade::log_level::info, s.str().c_str());
  }

  std::stringstream s;
  s << "init_swapchain"
    << "(colorspace: " << to_string(swapchain->get_color_space())
    << ")";
  reshade::log_message(reshade::log_level::info, s.str().c_str());
}

// AfterCreateRootSignature
static void on_init_pipeline_layout(
  reshade::api::device* device,
  const uint32_t paramCount,
  const reshade::api::pipeline_layout_param* params,
  reshade::api::pipeline_layout layout
) {
  logLayout(paramCount, params, layout);

  bool foundVisiblity = false;
  uint32_t cbvIndex = 0;
  uint32_t pcCount = 0;

  for (uint32_t paramIndex = 0; paramIndex < paramCount; ++paramIndex) {
    auto param = params[paramIndex];
    if (param.type == reshade::api::pipeline_layout_param_type::descriptor_table) {
      for (uint32_t rangeIndex = 0; rangeIndex < param.descriptor_table.count; ++rangeIndex) {
        auto range = param.descriptor_table.ranges[rangeIndex];
        if (range.type == reshade::api::descriptor_type::constant_buffer) {
          if (cbvIndex < range.dx_register_index + range.count) {
            cbvIndex = range.dx_register_index + range.count;
          }
        }
      }
    } else if (param.type == reshade::api::pipeline_layout_param_type::push_constants) {
      pcCount++;
      if (cbvIndex < param.push_constants.dx_register_index + param.push_constants.count) {
        cbvIndex = param.push_constants.dx_register_index + param.push_constants.count;
      }
    } else if (param.type == reshade::api::pipeline_layout_param_type::push_descriptors) {
      if (param.push_descriptors.type == reshade::api::descriptor_type::constant_buffer) {
        if (cbvIndex < param.push_descriptors.dx_register_index + param.push_descriptors.count) {
          cbvIndex = param.push_descriptors.dx_register_index + param.push_descriptors.count;
        }
      }
    }
  }

  uint32_t maxCount = 64u - (paramCount + 1u) + 1u;

  std::stringstream s;
  s << "on_init_pipeline_layout++("
    << reinterpret_cast<void*>(layout.handle)
    << " , max injections: " << (maxCount)
    << " )";
  reshade::log_message(reshade::log_level::info, s.str().c_str());
}

// After CreatePipelineState
static void on_init_pipeline(
  reshade::api::device* device,
  reshade::api::pipeline_layout layout,
  uint32_t subobjectCount,
  const reshade::api::pipeline_subobject* subobjects,
  reshade::api::pipeline pipeline
) {
  reshade::api::pipeline_subobject* newSubobjects = new reshade::api::pipeline_subobject[subobjectCount];
  memcpy(newSubobjects, subobjects, sizeof(reshade::api::pipeline_subobject) * subobjectCount);

  std::stringstream s;
  s << "on_init_pipeline("
    << reinterpret_cast<void*>(pipeline.handle)
    << " on " << reinterpret_cast<void*>(layout.handle)
    << ", subobjects: " << (subobjectCount)
    << " )";
  reshade::log_message(reshade::log_level::info, s.str().c_str());

  CachedPipeline* cachedPipeline = new CachedPipeline{
    pipeline,
    device,
    layout,
    newSubobjects,
    subobjectCount
  };

  for (uint32_t i = 0; i < subobjectCount; ++i) {
    switch (subobjects[i].type) {
      case reshade::api::pipeline_subobject_type::compute_shader:
        computeShaderLayouts.emplace(layout.handle);
      case reshade::api::pipeline_subobject_type::pixel_shader:
        break;
      default:
        {
          std::stringstream s;
          s << "on_init_pipeline("
            << reinterpret_cast<void*>(pipeline.handle)
            << ", subobject: " << to_string(subobjects[i].type)
            << " )";
          reshade::log_message(reshade::log_level::debug, s.str().c_str());
        }
        // likely should be cloned
        continue;
    }
    auto cloneSubject = &newSubobjects[i];
    auto desc = static_cast<reshade::api::shader_desc*>(cloneSubject->data);
    // Clone desc
    reshade::api::shader_desc clonedDesc;
    memcpy(&clonedDesc, desc, sizeof(reshade::api::shader_desc));
    // Point to cloned desc
    cloneSubject->data = &clonedDesc;

    if (desc->code_size == 0) continue;

    auto shader_hash = compute_crc32(static_cast<const uint8_t*>(desc->code), desc->code_size);

    // Cache shader
    CachedShader* cache = new CachedShader{
      malloc(desc->code_size),
      desc->code_size
    };
    memcpy(cache->data, desc->code, cache->size);
    shaderCacheCount++;
    shaderCacheSize += cache->size;
    shaderCache.emplace(shader_hash, cache);

    // Point to cached shader
    clonedDesc.code = cache->data;

    // Indexes
    cachedPipeline->shaderHash = shader_hash;
    pipelineCacheByShaderHash.emplace(shader_hash, cachedPipeline);

    // Metrics

    std::stringstream s;
    s << "caching shader("
      << "hash: 0x" << std::hex << shader_hash << std::dec
      << ", type: " << to_string(subobjects[i].type)
      << ", pipeline: " << reinterpret_cast<void*>(pipeline.handle)
      << ")";
    reshade::log_message(reshade::log_level::info, s.str().c_str());
  }
  pipelineCacheByPipelineHandle.emplace(pipeline.handle, cachedPipeline);
}

static void on_destroy_pipeline(
  reshade::api::device* device,
  reshade::api::pipeline pipeline
) {
  uint32_t changed = false;
  changed |= computeShaderLayouts.erase(pipeline.handle);
  auto pipelineCachePair = pipelineCacheByPipelineHandle.find(pipeline.handle);
  if (pipelineCachePair != pipelineCacheByPipelineHandle.end()) {
    free(pipelineCachePair->second);
    pipelineCacheByPipelineHandle.erase(pipeline.handle);
    changed = true;
  }

  auto pipelineClonePair = pipelineCloneMap.find(pipeline.handle);
  if (pipelineClonePair != pipelineCloneMap.end()) {
    pipelineCloneMap.erase(pipeline.handle);
    device->destroy_pipeline(pipelineClonePair->second);
    changed = true;
  }
  if (!changed) return;

  std::stringstream s;
  s << "on_destroy_pipeline("
    << reinterpret_cast<void*>(pipeline.handle)
    << ")";
  reshade::log_message(reshade::log_level::info, s.str().c_str());
}

// AfterSetPipelineState
static void on_bind_pipeline(
  reshade::api::command_list* cmd_list,
  reshade::api::pipeline_stage type,
  reshade::api::pipeline pipeline
) {
  const std::unique_lock<std::shared_mutex> lock(s_mutex);
  auto pipelineToClone = pipelineCloneMap.find(pipeline.handle);
  if (pipelineToClone != pipelineCloneMap.end()) {
    auto newPipeline = pipelineToClone->second;

    if (traceRunning) {
      std::stringstream s;
      s << "bind_pipeline(swapping pipeline "
        << reinterpret_cast<void*>(pipeline.handle)
        << " => " << reinterpret_cast<void*>(newPipeline.handle)
        << ", stage: " << to_string(type) << "(" << std::hex << (uint32_t)type << ")"
        << ")";
      reshade::log_message(reshade::log_level::info, s.str().c_str());
    }

    cmd_list->bind_pipeline(type, newPipeline);
  }

  if (!traceRunning) return;

  auto pair0 = pipelineCacheByPipelineHandle.find(pipeline.handle);
  if (pair0 == pipelineCacheByPipelineHandle.end()) return;
  auto cachedPipeline = pair0->second;

  bool isComputeShader = computeShaderLayouts.contains(cachedPipeline->layout.handle);

  if (listUnique) {
    auto traceCount = traceHashes.size();
    for (auto index = 0; index < traceCount; index++) {
      auto hash = traceHashes.at(index);
      if (hash == cachedPipeline->shaderHash) {
        traceHashes.erase(traceHashes.begin() + index);
        break;
      }
    }
  }
  if (cachedPipeline->shaderHash) {
    traceHashes.push_back(cachedPipeline->shaderHash);
  }

  std::stringstream s;
  s << "bind_pipeline("
    << traceHashes.size() << ": "
    << reinterpret_cast<void*>(cachedPipeline->pipeline.handle)
    << ", " << reinterpret_cast<void*>(cachedPipeline->layout.handle)
    << ", type: " << to_string(type) << " (" << std::hex << (uint32_t)type << std::dec << ")"
    << ", 0x" << std::hex << cachedPipeline->shaderHash << std::dec
    << ")";
  reshade::log_message(reshade::log_level::info, s.str().c_str());
}

static void on_bind_pipeline_states(
  reshade::api::command_list* cmd_list,
  uint32_t count,
  const reshade::api::dynamic_state* states,
  const uint32_t* values
) {
  if (!traceRunning) return;

  for (uint32_t i = 0; i < count; i++) {
    std::stringstream s;
    s << "bind_pipeline_state"
      << "(" << to_string(states[i])
      << ", " << values[i]
      << ")";
    reshade::log_message(reshade::log_level::info, s.str().c_str());
  }
}

static bool on_draw(
  reshade::api::command_list* cmd_list,
  uint32_t vertex_count,
  uint32_t instance_count,
  uint32_t first_vertex,
  uint32_t first_instance
) {
  if (traceRunning) {
    std::stringstream s;
    s << "on_draw"
      << "(" << vertex_count
      << ", " << instance_count
      << ", " << first_vertex
      << ", " << first_instance
      << ")";
    reshade::log_message(reshade::log_level::info, s.str().c_str());
  }
  return false;
}

static bool on_dispatch(reshade::api::command_list* cmd_list, uint32_t group_count_x, uint32_t group_count_y, uint32_t group_count_z) {
  if (traceRunning) {
    std::stringstream s;
    s << "on_dispatch"
      << "(" << group_count_x
      << ", " << group_count_y
      << ", " << group_count_z
      << ")";
    reshade::log_message(reshade::log_level::info, s.str().c_str());
  }
  return false;
}

static bool on_draw_indexed(
  reshade::api::command_list* cmd_list,
  uint32_t index_count,
  uint32_t instance_count,
  uint32_t first_index,
  int32_t vertex_offset,
  uint32_t first_instance
) {
  if (traceRunning) {
    std::stringstream s;
    s << "on_draw_indexed"
      << "(" << index_count
      << ", " << instance_count
      << ", " << first_index
      << ", " << vertex_offset
      << ", " << first_instance
      << ")";
    reshade::log_message(reshade::log_level::info, s.str().c_str());
  }
  return false;
}

static bool on_draw_or_dispatch_indirect(
  reshade::api::command_list* cmd_list,
  reshade::api::indirect_command type,
  reshade::api::resource buffer,
  uint64_t offset,
  uint32_t draw_count,
  uint32_t stride
) {
  if (traceRunning) {
    std::stringstream s;
    s << "on_draw_or_dispatch_indirect"
      << "(" << to_string(type)
      << ", " << reinterpret_cast<void*>(buffer.handle)
      << ", " << offset
      << ", " << draw_count
      << ", " << stride
      << ")";
    reshade::log_message(reshade::log_level::info, s.str().c_str());
  }
  return false;
}

static bool on_copy_texture_region(
  reshade::api::command_list* cmd_list,
  reshade::api::resource source,
  uint32_t source_subresource,
  const reshade::api::subresource_box* source_box,
  reshade::api::resource dest,
  uint32_t dest_subresource,
  const reshade::api::subresource_box* dest_box,
  reshade::api::filter_mode filter
) {
  if (traceRunning) {
    std::stringstream s;
    s << "on_copy_texture_region"
      << "(" << reinterpret_cast<void*>(source.handle)
      << ", " << (source_subresource)
      << ", " << reinterpret_cast<void*>(dest.handle)
      << ", " << (uint32_t)filter
      << ")";
    reshade::log_message(reshade::log_level::info, s.str().c_str());
  }
  return false;
}

static bool on_resolve_texture_region(
  reshade::api::command_list* cmd_list,
  reshade::api::resource source,
  uint32_t source_subresource,
  const reshade::api::subresource_box* source_box,
  reshade::api::resource dest,
  uint32_t dest_subresource,
  int32_t dest_x,
  int32_t dest_y,
  int32_t dest_z,
  reshade::api::format format
) {
  if (traceRunning) {
    std::stringstream s;
    s << "on_resolve_texture_region"
      << "(" << reinterpret_cast<void*>(source.handle)
      << ": " << (source_subresource)
      << " => " << reinterpret_cast<void*>(dest.handle)
      << ": " << (dest_subresource)
      << ", (" << dest_x << ", " << dest_y << ", " << dest_z << ") "
      << ")";
    reshade::log_message(reshade::log_level::info, s.str().c_str());
  }
  return false;
}

static bool on_copy_resource(
  reshade::api::command_list* cmd_list,
  reshade::api::resource source,
  reshade::api::resource dest
) {
  if (traceRunning) {
    std::stringstream s;
    s << "on_copy_resource"
      << "(" << reinterpret_cast<void*>(source.handle)
      << " => " << reinterpret_cast<void*>(dest.handle)
      << ")";
    reshade::log_message(reshade::log_level::info, s.str().c_str());
  }
  return false;
}

static void on_barrier(
  reshade::api::command_list* cmd_list,
  uint32_t count,
  const reshade::api::resource* resources,
  const reshade::api::resource_usage* old_states,
  const reshade::api::resource_usage* new_states
) {
  if (traceRunning) {
    for (uint32_t i = 0; i < count; i++) {
      std::stringstream s;
      s << "on_barrier("
        << reinterpret_cast<void*>(resources[i].handle)
        << ", " << std::hex << (uint32_t)old_states[i] << std::dec << " (" << to_string(old_states[i]) << ")"
        << " => " << std::hex << (uint32_t)new_states[i] << std::dec << " (" << to_string(new_states[i]) << ")"
        << ")"
        << "[" << i << "]";
      reshade::log_message(reshade::log_level::info, s.str().c_str());
    }
  }
}

static void on_bind_render_targets_and_depth_stencil(
  reshade::api::command_list* cmd_list,
  uint32_t count,
  const reshade::api::resource_view* rtvs,
  reshade::api::resource_view dsv
) {
  if (!traceRunning) return;

  if (count) {
    for (uint32_t i = 0; i < count; i++) {
      auto rtv = rtvs[i];
      std::stringstream s;
      s << "on_bind_render_targets("
        << reinterpret_cast<void*>(rtv.handle)
        << ")"
        << "[" << i << "]";
      reshade::log_message(reshade::log_level::info, s.str().c_str());
    }
  }
  if (dsv.handle) {
    std::stringstream s;
    s << "on_bind_depth_stencil("
      << reinterpret_cast<void*>(dsv.handle)
      << ")";
    reshade::log_message(reshade::log_level::info, s.str().c_str());
  }
}

static void on_init_resource(
  reshade::api::device* device,
  const reshade::api::resource_desc &desc,
  const reshade::api::subresource_data* initial_data,
  reshade::api::resource_usage initial_state,
  reshade::api::resource resource
) {
  if (!traceRunning && presentCount >= MAX_PRESENT_COUNT) return;
  bool warn = false;
  std::stringstream s;
  s << "init_resource("
    << reinterpret_cast<void*>(resource.handle)
    << ", flags: " << std::hex << (uint32_t)desc.flags << std::dec
    << ", state: " << std::hex << (uint32_t)initial_state << std::dec
    << ", type: " << to_string(desc.type);
  switch (desc.type) {
    case reshade::api::resource_type::buffer:
      s << ", size: " << desc.buffer.size;
      s << ", stride: " << desc.buffer.stride;
      break;
    case reshade::api::resource_type::texture_1d:
    case reshade::api::resource_type::texture_2d:
    case reshade::api::resource_type::texture_3d:
    case reshade::api::resource_type::surface:
      s << ", width: " << desc.texture.width
        << ", height: " << desc.texture.height
        << ", levels: " << desc.texture.levels
        << ", format: " << to_string(desc.texture.format);
      if (desc.texture.format == reshade::api::format::unknown) {
        warn = true;
      }
      break;
    default:
    case reshade::api::resource_type::unknown:
      break;
  }
  s << ")";
  reshade::log_message(
    warn
      ? reshade::log_level::warning
      : reshade::log_level::info,
    s.str().c_str()
  );
}

static void on_destroy_resource(reshade::api::device* device, reshade::api::resource resource) {
}

static void on_init_resource_view(
  reshade::api::device* device,
  reshade::api::resource resource,
  reshade::api::resource_usage usage_type,
  const reshade::api::resource_view_desc &desc,
  reshade::api::resource_view view
) {
  if (!traceRunning && presentCount >= MAX_PRESENT_COUNT) return;
  std::stringstream s;
  s << "init_resource_view("
    << reinterpret_cast<void*>(view.handle)
    << ", view type: " << to_string(desc.type)
    << ", view format: " << to_string(desc.format)
    << ", resource: " << reinterpret_cast<void*>(resource.handle)
    << ", resource usage: " << to_string(usage_type) << std::hex << (uint32_t)usage_type << std::dec;
  if (desc.type == reshade::api::resource_view_type::buffer) return;
  if (resource.handle) {
    const auto resourceDesc = device->get_resource_desc(resource);
    s << ", resource type: " << to_string(resourceDesc.type);

    switch (resourceDesc.type) {
      default:
      case reshade::api::resource_type::unknown:
        break;
      case reshade::api::resource_type::buffer:
        // if (!traceRunning) return;
        return;
        s << ", buffer offset: " << desc.buffer.offset;
        s << ", buffer size: " << desc.buffer.size;
        break;
      case reshade::api::resource_type::texture_1d:
      case reshade::api::resource_type::texture_2d:
      case reshade::api::resource_type::surface:
        s << ", texture format: " << to_string(resourceDesc.texture.format);
        s << ", texture width: " << resourceDesc.texture.width;
        s << ", texture height: " << resourceDesc.texture.height;
        break;
      case reshade::api::resource_type::texture_3d:
        s << ", texture format: " << to_string(resourceDesc.texture.format);
        s << ", texture width: " << resourceDesc.texture.width;
        s << ", texture height: " << resourceDesc.texture.height;
        s << ", texture depth: " << resourceDesc.texture.depth_or_layers;
        break;
    }
  }
  s << ")";
  reshade::log_message(reshade::log_level::info, s.str().c_str());
}

static void on_push_descriptors(
  reshade::api::command_list* cmd_list,
  reshade::api::shader_stage stages,
  reshade::api::pipeline_layout layout,
  uint32_t layout_param,
  const reshade::api::descriptor_table_update &update
) {
  if (!traceRunning || presentCount >= MAX_PRESENT_COUNT) return;
  for (uint32_t i = 0; i < update.count; i++) {
    std::stringstream s;
    s << "push_descriptors("
      << reinterpret_cast<void*>(layout.handle)
      << "[" << layout_param << "]";
    switch (update.type) {
      case reshade::api::descriptor_type::sampler:
        {
          auto item = static_cast<const reshade::api::sampler*>(update.descriptors)[i];
          s << ", sampler: " << reinterpret_cast<void*>(item.handle);
        }
        break;
      case reshade::api::descriptor_type::sampler_with_resource_view:
        {
          auto item = static_cast<const reshade::api::sampler_with_resource_view*>(update.descriptors)[i];
          s << ", sampler: " << reinterpret_cast<void*>(item.sampler.handle);
          s << ", rsv: " << reinterpret_cast<void*>(item.view.handle);
        }
        break;
      case reshade::api::descriptor_type::shader_resource_view:
        {
          auto item = static_cast<const reshade::api::resource_view*>(update.descriptors)[i];
          s << ", shaderrsv: " << reinterpret_cast<void*>(item.handle);
        }
        break;
      case reshade::api::descriptor_type::unordered_access_view:
        {
          auto item = static_cast<const reshade::api::resource_view*>(update.descriptors)[i];
          s << ", uav: " << reinterpret_cast<void*>(item.handle);
        }
        break;
      case reshade::api::descriptor_type::acceleration_structure:
        {
          auto item = static_cast<const reshade::api::resource_view*>(update.descriptors)[i];
          s << ", accl: " << reinterpret_cast<void*>(item.handle);
        }
        break;
      case reshade::api::descriptor_type::constant_buffer:
        {
          auto item = static_cast<const reshade::api::buffer_range*>(update.descriptors)[i];
          s << ", buffer: " << reinterpret_cast<void*>(item.buffer.handle);
          s << ", size: " << item.size;
          s << ", offset: " << item.offset;
        }
        break;
      default:
        break;
    }

    s << ")";
    s << "[" << i << "/" << update.count << "]";
    reshade::log_message(reshade::log_level::info, s.str().c_str());
  }
}

static void on_bind_descriptor_tables(
  reshade::api::command_list*,
  reshade::api::shader_stage stages,
  reshade::api::pipeline_layout layout,
  uint32_t first,
  uint32_t count,
  const reshade::api::descriptor_table* tables
) {
  if (!traceRunning || presentCount >= MAX_PRESENT_COUNT) return;

  for (uint32_t i = 0; i < count; ++i) {
    std::stringstream s;
    s << "bind_descriptor_table("
      << reinterpret_cast<void*>(layout.handle)
      << std::hex << (uint32_t)stages << std::dec
      << ", index: " << (first + i)
      << ", table: " << reinterpret_cast<void*>(tables[i].handle)
      << ") [" << i << "]";
    reshade::log_message(reshade::log_level::info, s.str().c_str());
  }
}

static bool on_copy_descriptor_tables(
  reshade::api::device* device,
  uint32_t count,
  const reshade::api::descriptor_table_copy* copies
) {
  if (!traceRunning) return false;
  for (uint32_t i = 0; i < count; i++) {
    auto copy = copies[i];

    std::stringstream s;
    s << "copy_descriptor_tables("
      << reinterpret_cast<void*>(copy.source_table.handle)
      << "[" << copy.source_binding << "]"
      << "[" << copy.source_array_offset << "]"
      << " => "
      << reinterpret_cast<void*>(copy.dest_table.handle)
      << "[" << copy.dest_binding << "]"
      << "[" << copy.dest_array_offset << "]"
      << ", count: " << copy.count
      << ") [" << i << "]";
    reshade::log_message(reshade::log_level::info, s.str().c_str());
  }

  return false;
}

static bool on_update_descriptor_tables(
  reshade::api::device* device,
  uint32_t count,
  const reshade::api::descriptor_table_update* updates
) {
  if (!traceRunning || presentCount >= MAX_PRESENT_COUNT) return false;
  for (uint32_t i = 0; i < count; i++) {
    auto update = updates[i];

    std::stringstream s;
    s << "update_descriptor_tables("
      << reinterpret_cast<void*>(update.table.handle)
      << "[" << update.binding << "]"
      << "[" << update.array_offset << "]";
    for (uint32_t j = 0; j < update.count; j++) {
      switch (update.type) {
        case reshade::api::descriptor_type::sampler:
          {
            auto item = static_cast<const reshade::api::sampler*>(update.descriptors)[j];
            s << ", sampler: " << reinterpret_cast<void*>(item.handle);
          }
          break;
        case reshade::api::descriptor_type::sampler_with_resource_view:
          {
            auto item = static_cast<const reshade::api::sampler_with_resource_view*>(update.descriptors)[j];
            s << ", sampler: " << reinterpret_cast<void*>(item.sampler.handle);
            s << ", rsv: " << reinterpret_cast<void*>(item.view.handle);
          }
          break;
        case reshade::api::descriptor_type::shader_resource_view:
          {
            auto item = static_cast<const reshade::api::resource_view*>(update.descriptors)[j];
            s << ", shaderrsv: " << reinterpret_cast<void*>(item.handle);
          }
          break;
        case reshade::api::descriptor_type::unordered_access_view:
          {
            auto item = static_cast<const reshade::api::resource_view*>(update.descriptors)[j];
            s << ", uav: " << reinterpret_cast<void*>(item.handle);
          }
          break;
        case reshade::api::descriptor_type::acceleration_structure:
          {
            auto item = static_cast<const reshade::api::resource_view*>(update.descriptors)[j];
            s << ", accl: " << reinterpret_cast<void*>(item.handle);
          }
          break;
        case reshade::api::descriptor_type::constant_buffer:
          {
            auto item = static_cast<const reshade::api::buffer_range*>(update.descriptors)[j];
            s << ", buffer: " << reinterpret_cast<void*>(item.buffer.handle);
            s << ", size: " << item.size;
            s << ", offset: " << item.offset;
          }
          break;
        default:
          break;
      }
    }

    s << ") [" << i << "]";
    reshade::log_message(reshade::log_level::info, s.str().c_str());
  }
  return false;
}

void on_push_constants(
  reshade::api::command_list* cmd_list,
  reshade::api::shader_stage stages,
  reshade::api::pipeline_layout layout,
  uint32_t layout_param,
  uint32_t first,
  uint32_t count,
  const void* values
) {
  if (!traceRunning || presentCount >= MAX_PRESENT_COUNT) return;
  std::stringstream s;
  s << "push_constants("
    << reinterpret_cast<void*>(layout.handle)
    << "[" << layout_param << "]"
    << ", stage: " << std::hex << (uint32_t)stages << std::dec << " (" << to_string(stages) << ")"
    << ", count: " << count
    << "{ 0x";
  for (uint32_t i = 0; i < count; i++) {
    s << std::hex << static_cast<const uint32_t*>(values)[i] << std::dec << ", ";
  }
  s << " })";

  reshade::log_message(reshade::log_level::info, s.str().c_str());
}

static void on_reshade_present(reshade::api::effect_runtime* runtime) {
  if (traceRunning) {
    reshade::log_message(reshade::log_level::info, "present()");
    reshade::log_message(reshade::log_level::info, "--- End Frame ---");
    traceCount = traceHashes.size();
    traceRunning = false;
  } else if (traceScheduled) {
    traceScheduled = false;
    traceHashes.clear();
    traceRunning = true;
    reshade::log_message(reshade::log_level::info, "--- Frame ---");
  }
  if (presentCount <= MAX_PRESENT_COUNT) {
    presentCount++;
  }
  if (needsLiveReload) {
    loadLiveShaders();
    needsLiveReload = false;
  }
}

static const char* findFXC() {
  std::string path = "C:\\Program Files (x86)\\Windows Kits\\10\\bin";
  if (std::filesystem::exists(path) == false) return NULL;

  for (const auto &entry : std::filesystem::directory_iterator(path)) {
    auto fullPath = entry.path();
    fullPath.append(".\\x64\\fxc.exe");
    if (std::filesystem::exists(fullPath)) {
      return fullPath.generic_string().c_str();
    }
  }
  return NULL;
}

std::string exec(const char* cmd) {
  std::array<char, 128> buffer;
  std::string result;
  std::unique_ptr<FILE, decltype(&_pclose)> pipe(_popen(cmd, "r"), _pclose);
  if (!pipe) {
    throw std::runtime_error("popen() failed!");
  }
  while (fgets(buffer.data(), static_cast<int>(buffer.size()), pipe.get()) != nullptr) {
    result += buffer.data();
  }
  return result;
}

void dumpShader(uint32_t shader_hash) {
  auto dump_path = getShaderPath();

  if (std::filesystem::exists(dump_path) == false) {
    std::filesystem::create_directory(dump_path);
  }
  wchar_t hash_string[11];
  swprintf_s(hash_string, L"0x%08X", shader_hash);

  dump_path /= hash_string;
  dump_path += L".cso";

  auto cachedShader = shaderCache.find(shader_hash)->second;

  std::ofstream file(dump_path, std::ios::binary);

  file.write(static_cast<const char*>(cachedShader->data), cachedShader->size);
}

char* dumpFXC(uint32_t shader_hash, bool force = false) {
  auto fxcExePath = findFXC();
  if (fxcExePath == NULL) {
    reshade::log_message(reshade::log_level::warning, "fxc.exe not found.");
    return nullptr;
  }

  // Prepend executable directory to image files
  auto shaderPath = getShaderPath();
  if (std::filesystem::exists(shaderPath) == false) {
    std::filesystem::create_directory(shaderPath);
  }

  auto csoPath = shaderPath;
  wchar_t hash_string[11];
  swprintf_s(hash_string, L"0x%08X", shader_hash);

  csoPath /= hash_string;
  auto fxcPath = csoPath;

  csoPath += L".cso";
  fxcPath += L".fxc";

  if (std::filesystem::exists(fxcPath) == false) {
    if (std::filesystem::exists(csoPath) == false) {
      dumpShader(shader_hash);
    }

    std::stringstream command;
    command << "\""
            << "\""
            << fxcExePath
            << "\""
            << " -dumpbin "
            << "\""
            << csoPath.generic_string()
            << "\" > \""
            << fxcPath.generic_string()
            << "\""
            << "\"";

    // Causes application focus to blur
    std::system(command.str().c_str());
  }

  std::ifstream file(fxcPath, std::ios::binary);

  file.seekg(0, std::ios::end);
  size_t fileSize = file.tellg();
  char* code = reinterpret_cast<char*>(malloc((fileSize + 1) * sizeof(char)));
  file.seekg(0, std::ios::beg).read(code, fileSize);
  code[fileSize] = NULL;

  return code;
}

// @see https://pthom.github.io/imgui_manual_online/manual/imgui_manual.html
static void on_register_overlay(reshade::api::effect_runtime* runtime) {
  if (ImGui::Button("Trace")) {
    traceScheduled = true;
  }
  ImGui::SameLine();
  ImGui::Text("Traced Shaders: %d", traceCount);
  ImGui::Checkbox("List Unique Only", &listUnique);

  ImGui::Text("Cached Shaders: %d", shaderCacheCount);
  ImGui::SameLine();
  if (ImGui::Button("Dump All")) {
    for (auto shader : shaderCache) {
      dumpShader(shader.first);
    }
  }

  if (ImGui::Button("Load Live Shaders")) {
    needsLiveReload = true;
  }

  ImGui::Text("Cached Shaders Size: %d", shaderCacheSize);
  static int32_t selectedIndex = -1;
  bool changedSelected = false;
  if (ImGui::BeginChild("HashList", ImVec2(100, -FLT_MIN), ImGuiChildFlags_ResizeX)) {
    if (ImGui::BeginListBox("##HashesListbox", ImVec2(-FLT_MIN, -FLT_MIN))) {
      if (!traceRunning) {
        for (auto index = 0; index < traceCount; index++) {
          auto hash = traceHashes.at(index);
          const bool isSelected = (selectedIndex == index);
          auto pair = pipelineCacheByShaderHash.find(hash);
          const bool isCloned = pair != pipelineCacheByShaderHash.end() && pair->second->cloned;
          std::stringstream name;
          name << std::setfill('0') << std::setw(3) << index << std::setw(0)
               << " - 0x" << std::hex << hash;
          if (isCloned) {
            name << "*";
          }
          if (ImGui::Selectable(name.str().c_str(), isSelected)) {
            selectedIndex = index;
            changedSelected = true;
          }

          if (isSelected) {
            ImGui::SetItemDefaultFocus();
          }
        }
      }
      ImGui::EndListBox();
    }
    ImGui::EndChild();
  }

  ImGui::SameLine();

  static std::string sourceCode = "";
  if (ImGui::BeginChild("HashDetails", ImVec2(-FLT_MIN, -FLT_MIN))) {
    ImGui::BeginDisabled(selectedIndex == -1);
    if (changedSelected) {
      auto hash = traceHashes.at(selectedIndex);
      auto cache = shaderCache.find(hash)->second;
      if (cache->source.length() == 0) {
        char* fxc = dumpFXC(hash);
        if (fxc == nullptr) {
          cache->source.assign("Decompilation failed.");
        } else {
          cache->source.assign(fxc);
          free(fxc);
        }
      }
      sourceCode.assign(cache->source);
    }

    if (ImGui::BeginChild("HashSourceCode", ImVec2(-FLT_MIN, -FLT_MIN), ImGuiChildFlags_None, ImGuiWindowFlags_HorizontalScrollbar | ImGuiWindowFlags_AlwaysVerticalScrollbar)) {
      ImGui::InputTextMultiline(
        "##source",
        (char*)sourceCode.c_str(),
        sourceCode.length(),
        ImVec2(-FLT_MIN, -FLT_MIN),
        ImGuiInputTextFlags_ReadOnly
      );
      ImGui::EndChild();
    }
    ImGui::EndChild();
    ImGui::EndDisabled();
  }
}

BOOL APIENTRY DllMain(HMODULE hModule, DWORD fdwReason, LPVOID) {
  switch (fdwReason) {
    case DLL_PROCESS_ATTACH:
      if (!reshade::register_addon(hModule)) return FALSE;

      reshade::register_event<reshade::addon_event::init_swapchain>(on_init_swapchain);
      reshade::register_event<reshade::addon_event::init_pipeline_layout>(on_init_pipeline_layout);
      reshade::register_event<reshade::addon_event::init_pipeline>(on_init_pipeline);
      reshade::register_event<reshade::addon_event::destroy_pipeline>(on_destroy_pipeline);

      reshade::register_event<reshade::addon_event::bind_pipeline>(on_bind_pipeline);
      reshade::register_event<reshade::addon_event::bind_pipeline_states>(on_bind_pipeline_states);

      reshade::register_event<reshade::addon_event::init_resource>(on_init_resource);
      reshade::register_event<reshade::addon_event::destroy_resource>(on_destroy_resource);
      reshade::register_event<reshade::addon_event::init_resource_view>(on_init_resource_view);

      reshade::register_event<reshade::addon_event::push_descriptors>(on_push_descriptors);
      reshade::register_event<reshade::addon_event::bind_descriptor_tables>(on_bind_descriptor_tables);
      reshade::register_event<reshade::addon_event::copy_descriptor_tables>(on_copy_descriptor_tables);
      reshade::register_event<reshade::addon_event::update_descriptor_tables>(on_update_descriptor_tables);
      reshade::register_event<reshade::addon_event::push_constants>(on_push_constants);

      reshade::register_event<reshade::addon_event::draw>(on_draw);
      reshade::register_event<reshade::addon_event::dispatch>(on_dispatch);
      reshade::register_event<reshade::addon_event::draw_indexed>(on_draw_indexed);
      reshade::register_event<reshade::addon_event::draw_or_dispatch_indirect>(on_draw_or_dispatch_indirect);
      reshade::register_event<reshade::addon_event::bind_render_targets_and_depth_stencil>(on_bind_render_targets_and_depth_stencil);

      reshade::register_event<reshade::addon_event::copy_texture_region>(on_copy_texture_region);
      reshade::register_event<reshade::addon_event::resolve_texture_region>(on_resolve_texture_region);

      reshade::register_event<reshade::addon_event::copy_resource>(on_copy_resource);

      reshade::register_event<reshade::addon_event::barrier>(on_barrier);

      reshade::register_event<reshade::addon_event::reshade_present>(on_reshade_present);

      reshade::register_overlay("RenoDX (DevKit)", on_register_overlay);

      break;
    case DLL_PROCESS_DETACH:
      reshade::unregister_event<reshade::addon_event::init_swapchain>(on_init_swapchain);
      reshade::unregister_event<reshade::addon_event::init_pipeline_layout>(on_init_pipeline_layout);

      reshade::unregister_event<reshade::addon_event::init_pipeline>(on_init_pipeline);
      reshade::unregister_event<reshade::addon_event::destroy_pipeline>(on_destroy_pipeline);

      reshade::unregister_event<reshade::addon_event::bind_pipeline>(on_bind_pipeline);

      reshade::unregister_event<reshade::addon_event::copy_texture_region>(on_copy_texture_region);

      reshade::unregister_event<reshade::addon_event::reshade_present>(on_reshade_present);

      reshade::unregister_overlay("RenoDX (DevKit)", on_register_overlay);

      reshade::unregister_addon(hModule);
      break;
  }

  return TRUE;
}
