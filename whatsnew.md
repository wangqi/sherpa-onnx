# Sherpa-ONNX Upgrade to v1.12.20

## Overview

This document summarizes the upgrade from sherpa-onnx v1.12.15 to v1.12.20 (December 2025).

**Upgrade Date**: December 27, 2025
**Previous Version**: 1.12.15
**New Version**: 1.12.20

---

## New Features

### ASR (Automatic Speech Recognition)

#### 1. Google MedASR CTC Model Support (#2935)
- **Purpose**: Medical speech recognition optimized for healthcare terminology
- **Platforms**: All platforms including iOS
- **API**: New `OfflineRecognizer.from_medasr_ctc()` factory method
- **Benefits**: Specialized medical vocabulary recognition for clinical applications

#### 2. Fun-ASR-Nano-2512 Support (#2906)
Comprehensive multi-dialect and multi-language ASR model with:

| Feature | Description |
|---------|-------------|
| **Far-field Recognition** | Optimized for distance pickup and high-noise scenarios (93% accuracy) |
| **Chinese Dialects** | 7 major dialects: Wu, Cantonese, Min, Hakka, Gan, Xiang, Jin |
| **Regional Accents** | 26 regions including Henan, Sichuan, Guangdong, etc. |
| **Multi-language** | 31 languages with East/Southeast Asian focus |
| **Music Background** | Enhanced lyric recognition under music interference |

#### 3. GigaAM v3 Export (#2901)
- New generation of ASR models exported to sherpa-onnx format

### TTS (Text-to-Speech)

#### 1. Matcha TTS Chinese+English (#2882, #2885)
- APK builds for Matcha TTS supporting mixed Chinese+English synthesis
- WASM space deployment for web applications
- Improved space handling between English words (#2858)

#### 2. Zipvoice Improvements (#2887, #2890, #2892, #2894)
- New testing scripts for Zipvoice ONNX models
- Uploaded optimized Zipvoice ONNX models
- **Removed cppinyin dependency** - simplified build process
- Shorter, cleaner model naming conventions

### NPU/Accelerator Support

#### 1. Qualcomm NPU (QNN) for Paraformer (#2931, #2932)
- C++ runtime for Paraformer ASR with QNN acceleration
- Android demo application
- QNN context binary loading for faster startup (#2877)

#### 2. Axera NPU Support (#2867, #2870, #2872)
- Support for Axera ax630, ax650, and axcl backends
- CI integration for Axera NPU testing
- Refactored examples for better integration

#### 3. Ascend 910B4 Export (#2878)
- Model export support for Huawei Ascend AI processors

### Other Improvements

- **Streaming VAD optimization** (#2876): Better output when no voice detected for extended periods
- **SenseVoice refactoring** (#2873): Cleaner implementation
- **Paraformer refactoring** (#2874): Improved code structure
- **Token-level confidence scores** (#2843): For offline transducer models
- **Spacemit RISC-V support** (#2837): New CPU platform support

---

## Bug Fixes

| Issue | Fix |
|-------|-----|
| #2939 | Fixed Ort::Value tensor view creation - corrected memory info handling |
| #2909 | Fixed NPM package publishing |
| #2905 | Fixed typos in URLs |
| #2893 | Fixed build errors |
| #2838 | Fixed building without TTS for C API |

---

## Build System Changes

### Library Dependency Removal
**Critical Change**: `libcppinyin_core.a` has been removed from the build:

```diff
# build-ios.sh changes
- for f in libcppinyin_core.a libkaldi-native-fbank-core.a ...
+ for f in libkaldi-native-fbank-core.a ...

# libtool merge changes
- build/simulator/lib/libcppinyin_core.a \
  build/simulator/lib/libkaldi-native-fbank-core.a \
```

This simplifies the build and removes the cppinyin pinyin library dependency from core sherpa-onnx.

### CI/Platform Updates
- Updated macOS CI from `macos-13` to `macos-15-intel`
- Swift workflow updates for new macOS runners
- Updated Flutter plugin versions to 1.12.20

---

## iOS/macOS Specific Changes

### Swift API Updates
- Error message improvements in `SherpaOnnx.swift` (better audio generation error reporting)
- Model configuration updates for new ASR models

### Build Script Changes
The upstream `build-ios.sh` and `build-swift-macos.sh` scripts have been modified to:
1. Remove `libcppinyin_core.a` from library merging
2. Simplify the static library linking process

---

## Risk Assessment

### High Risk

| Risk | Description | Mitigation |
|------|-------------|------------|
| **API Compatibility** | New ASR model types (MedASR, Fun-ASR-Nano) add new config structures | Verify Swift wrapper compatibility; add new model support if needed |
| **cppinyin Removal** | Pinyin functionality may be affected if directly used | Review if any code depends on cppinyin; most iOS apps use higher-level APIs |

### Medium Risk

| Risk | Description | Mitigation |
|------|-------------|------------|
| **Memory Info Change** | Ort::Value view creation now uses tensor's own memory info (#2939) | Verify TTS/ASR operations work correctly |
| **Build Script Sync** | Library list changes in build scripts | Ensure custom build scripts don't reference removed libraries |

### Low Risk

| Risk | Description | Mitigation |
|------|-------------|------------|
| **QNN/NPU Changes** | Qualcomm/Axera NPU features | Android-only; no iOS impact |
| **CI Platform Updates** | macOS runner changes | Build automation concern only |

---

## Custom Build Script Analysis

### `build-xcframework.sh` Status: **NO CHANGES REQUIRED**

The custom `build-xcframework.sh` script at `thirdparty/sherpa-onnx/build-xcframework.sh` is a wrapper that:

1. Calls `./build-ios.sh` to generate iOS xcframework
2. Calls `./build-swift-macos.sh` to generate macOS xcframework
3. Merges them into a unified `build-apple/sherpa-onnx.xcframework`

Since the library changes (cppinyin removal) are handled internally by the upstream scripts, the wrapper script correctly delegates to them and **does not need modification**.

### Verification Checklist

- [ ] Rebuild xcframework with updated sherpa-onnx
- [ ] Verify TTS synthesis works (Kokoro model)
- [ ] Verify VAD detection works (Silero VAD)
- [ ] Verify ASR works if used (Whisper/Paraformer)
- [ ] Check for any Swift compilation warnings
- [ ] Test on both iOS device and simulator
- [ ] Verify macOS Catalyst build works

---

## Migration Notes

### For Existing Code

No breaking changes for existing functionality. The upgrade is backward compatible with:
- Existing TTS models (Kokoro, Matcha, VITS)
- Existing VAD models (Silero VAD)
- Existing ASR models (Whisper, SenseVoice)

### For New Features

To use new ASR models, additional Swift API wrappers may need to be added:

```swift
// Example: Future MedASR support might look like
let config = OfflineMedAsrCtcModelConfig(
    model: "path/to/model.onnx"
)
```

---

## Recommended Actions

1. **Rebuild xcframework**: Run `./build-xcframework.sh` to generate updated binaries
2. **Test existing functionality**: Verify TTS/VAD/ASR continue working
3. **Update wrapper if needed**: Add Swift wrappers for new model types if required
4. **Review memory usage**: The Ort::Value fix may affect memory patterns

---

## References

- [Sherpa-ONNX GitHub Releases](https://github.com/k2-fsa/sherpa-onnx/releases)
- [Sherpa-ONNX Documentation](https://k2-fsa.github.io/sherpa/onnx/)
- [Fun-ASR-Nano Model](https://huggingface.co/FunAudioLLM/Fun-ASR-Nano-2512)
- [Google MedASR](https://github.com/Google-Health/medasr)
