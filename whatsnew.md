# Sherpa-ONNX Upgrade to v1.12.22

## Overview

This document summarizes the upgrade from sherpa-onnx v1.12.20 to v1.12.22 (January 2026).

**Upgrade Date**: January 14, 2026
**Previous Version**: 1.12.20
**New Version**: 1.12.22

---

## Version 1.12.22 Changes

### New Features
- **Nemotron Speech Streaming Support** (#3044, #3045)
  - Added support for `nvidia/nemotron-speech-streaming-en-0.6b` model
  - INT8 quantized version available for smaller footprint
  - APK builds for Android

### Bug Fixes
- Fixed SHA256 for onnxruntime Linux x86_64 GPU package (#3042)
- Fixed checking FunASR Nano tokenizer on Windows (#3043)
- Fixed building Linux arm wheels (#3047)
- Updated WAV files for FunASR Nano testing (#3038)

---

## Version 1.12.21 Changes

### ASR (Automatic Speech Recognition)

#### 1. Google MedASR CTC Model Support (#2934, #2935, #2946, #2947)
- **Purpose**: Medical speech recognition optimized for healthcare terminology
- **Platforms**: All platforms including iOS and macOS
- **Swift API**: New `SherpaOnnxOfflineMedAsrCtcModelConfig` structure added
- **Benefits**: Specialized medical vocabulary recognition for clinical applications

#### 2. FunASR-Nano with LLM Support (#2936, #2978, #2994, #2995, #3022)
- Comprehensive ASR with LLM-powered post-processing
- **Swift API Support** (#2994, #3022): New `SherpaOnnxOfflineFunAsrNanoModelConfig`
- Updated CTC model for better accuracy
- Unified KV-cache LLM architecture

| Feature | Description |
|---------|-------------|
| **Swift API** | Full Swift bindings for FunASR Nano |
| **LLM Integration** | Built-in language model for improved transcription |
| **Multi-language** | Supports Chinese and English |

#### 3. Whisper Improvements (#3023)
- Improved ORT IO binding execution for Whisper models
- Better performance through optimized memory access patterns

#### 4. Fire-Red-ASR ORT I/O Binding (#3011)
- Enabled ORT I/O binding for encoder/decoder
- Improved inference performance

### TTS (Text-to-Speech)

#### 1. TTS Engine Speed Fix (#2895)
- Fixed engine speed calculation for more accurate playback rates

#### 2. MeloTTS V-words Fix (#3002)
- Fixed pronunciation of V-words in MeloTTS English models

### Build System Updates

#### ONNX Runtime Version Migration
Started migration from onnxruntime 1.17.1 to v1.23.2:
- Linux x64 with NVIDIA GPU (#3018)
- Linux aarch64 (#3016)
- Linux arm (#3017)
- Windows (#3007)

**Note**: iOS/macOS builds continue using onnxruntime 1.17.1 for stability.

### NPU/Accelerator Support

#### 1. Qualcomm NPU (QNN) Improvements
- Exported more Zipformer CTC models to QNN (#2921)
- Exported Paraformer ASR models to QNN (#2925)
- C++ runtime for Paraformer with QNN acceleration (#2931)
- Android demo for Paraformer with QNN (#2932)

#### 2. Ascend NPU Support
- Whisper export to Ascend NPU (#3008)
- C++ runtime for Whisper with Ascend NPU (#3009)
- Test Whisper on Ascend NPU using ACL Python API (#2986)

#### 3. Rockchip NPU
- Whisper export to RK NPU (#2983)

### Other Improvements

- **Keyword Spotting**: Added phone+pinyin tokenization with lexicon support (#2922)
- **Eigen Optimization**: Optimized computation with Eigen library (#2928)
- **Matrix Operations**: Added Transpose for 2-D matrix (#2926)
- **Build Compatibility**: Fixed building for onnxruntime >= 1.11.0 (#2981)
- **HarmonyOS**: Fixed building for HarmonyOS (#2972)
- **Go API**: Refactored and reformatted Go API code (#2975, #2976, #2979)

---

## iOS/macOS Specific Changes

### Swift API Additions

#### 1. FunASR Nano Swift API (#2994, #3022)
New Swift wrapper for FunASR Nano models:
```swift
// New configuration structure in SherpaOnnx.swift
SherpaOnnxOfflineFunAsrNanoModelConfig
```

#### 2. Google MedASR Swift API (#2947)
New Swift wrapper for MedASR models:
```swift
// New configuration structure in SherpaOnnx.swift
SherpaOnnxOfflineMedAsrCtcModelConfig
```

### Build Script Updates

The `build-ios-shared.sh` script received minor updates for consistent library handling.

---

## Risk Assessment

### Low Risk

| Risk | Description | Mitigation |
|------|-------------|------------|
| **New API Additions** | FunASR Nano and MedASR add new config structures | These are additive changes; existing code unaffected |
| **ONNX Runtime** | iOS/macOS still use 1.17.1 | No change for Apple platforms |
| **Nemotron Model** | New streaming ASR model | Optional feature; no impact unless used |

### Medium Risk

| Risk | Description | Mitigation |
|------|-------------|------------|
| **Swift API Changes** | New structures in SherpaOnnx.swift | Update sherpa-onnx_swift wrapper if using new models |
| **Whisper IO Binding** | Performance optimization changes | Test existing Whisper workflows |

### No High Risks Identified

This is a minor version upgrade (1.12.20 -> 1.12.22) with:
- No breaking API changes
- No removal of existing functionality
- Additive new features only
- iOS ONNX Runtime version unchanged

---

## Custom Build Script Analysis

### `build-xcframework.sh` Status: **NO CHANGES REQUIRED**

The custom `build-xcframework.sh` script continues to work correctly because:

1. **Wrapper Architecture**: Delegates to upstream scripts (`build-ios.sh`, `build-swift-macos.sh`, `build-maccatalyst.sh`)
2. **Library List**: No libraries added or removed in this release
3. **ONNX Runtime**: iOS continues using v1.17.1 (no version mismatch)
4. **Platform Support**: All three platforms (iOS, macOS, Mac Catalyst) build without changes

### Verification Status

The build scripts have been verified:

| Script | Status | Notes |
|--------|--------|-------|
| `build-ios.sh` | Compatible | Uses onnxruntime 1.17.1 |
| `build-swift-macos.sh` | Compatible | No breaking changes |
| `build-maccatalyst.sh` | Compatible | No breaking changes |
| `build-xcframework.sh` | Compatible | Wrapper script unchanged |

---

## sherpa-onnx_swift Package Impact

### Required Updates

If you want to use the new models (FunASR Nano, MedASR), update `sherpa-onnx_swift`:

1. **Copy Updated c-api.h**: The header file may have new structures
2. **Add Swift Wrappers**: Create Swift-friendly wrappers for new config types
3. **Update SherpaOnnx.swift**: Sync with upstream Swift API examples

### No Updates Required For

- Existing TTS functionality (Kokoro-82M)
- Existing VAD functionality (Silero VAD)
- Existing ASR functionality (Whisper, SenseVoice)

---

## Recommended Actions

1. **Rebuild xcframework**:
   ```bash
   cd thirdparty/sherpa-onnx
   ./build-xcframework.sh
   ```

2. **Test existing functionality**:
   - [ ] TTS synthesis (Kokoro model)
   - [ ] VAD detection (Silero VAD)
   - [ ] ASR if used (Whisper)

3. **Optional - Add new model support**:
   - Update sherpa-onnx_swift to support FunASR Nano
   - Update sherpa-onnx_swift to support MedASR

---

## References

- [Sherpa-ONNX v1.12.22 Release](https://github.com/k2-fsa/sherpa-onnx/releases/tag/v1.12.22)
- [Sherpa-ONNX v1.12.21 Release](https://github.com/k2-fsa/sherpa-onnx/releases/tag/v1.12.21)
- [Nemotron Speech Streaming Model](https://huggingface.co/nvidia/nemotron-speech-streaming-en-0.6b)
- [FunASR Nano Models](https://huggingface.co/FunAudioLLM)
- [Google MedASR](https://github.com/Google-Health/medasr)
