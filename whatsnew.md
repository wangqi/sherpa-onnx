# sherpa-onnx Upgrade: v1.12.22 → v1.13.0

**Merged:** 2026-05-05  
**Upstream:** https://github.com/k2-fsa/sherpa-onnx  
**Intermediate releases covered:** v1.12.23 – v1.12.40, v1.13.0

---

## New Model Support

### Speech Recognition (ASR)
- **Qwen3-ASR** (Alibaba, v1.12.34–v1.12.36): Offline multilingual ASR based on the Qwen3 architecture. Supports hotwords, per-stream language hints, and fp32 + int8 quantized variants. Full Swift, C, C++, Java, Go, Rust, Dart, JavaScript, C#, and Pascal APIs added.
- **Moonshine v2** (v1.12.28): Updated streaming-capable ASR model with Swift, C/C++, Java, Go, Rust, Dart, JavaScript, C#, Pascal APIs.
- **Cohere Transcribe** (v1.12.35): 14-language offline ASR from CohereLabs (`cohere-transcribe-03-2026`). Full API coverage including Swift.
- **NVIDIA Parakeet Unified en-0.6B** (v1.13.0): Export of the nvidia/parakeet-unified-en-0.6b English ASR model to sherpa-onnx format.
- **nemotron-speech-streaming-en-0.6b** (v1.13.0): Updated streaming English ASR model.
- **FunASR Nano int8** (v1.12.37): Updated int8 quantized FunASR Nano models.
- **Canary model** (v1.12.29): Support for dynamic decoder layers in runtime.

### Text-to-Speech (TTS)
- **Supertonic TTS** (v1.12.29): New neural TTS engine; Swift, C++, Java, Kotlin, Go, C#, Dart, Pascal, JavaScript APIs added. Models uploaded to HuggingFace.
- **ZipVoice TTS** (v1.12.30): New zero-shot TTS model with callback API. Full multi-language binding coverage including Swift.
- **Piper TTS Expansion** (v1.12.40): Additional Piper TTS voices including two Chinese models and an Albanian (sq_AL) voice from LanguageWeaver.

### Speech Enhancement / Denoising
- **DPDFNet** (v1.12.30): Offline and streaming speech denoiser. C, C++, Python, C#, Go, Rust APIs available.
- **GTCRN Online Denoiser** (v1.12.30): Real-time low-latency streaming speech denoiser. Python and C API examples available.

---

## New Features

### Audio Source Separation (v1.12.34–v1.12.35)
A new audio source separation capability separates mixed audio into individual source streams. Swift, C, C++, Go APIs added.

### SetOption / GetOption for Streams (v1.12.30)
A generic `SetOption(key, value)` / `GetOption(key)` / `HasOption(key)` API has been added to both `OnlineStream` and `OfflineStream`. This enables per-stream runtime configuration without breaking the existing constructor API. Language bindings: C, C++, Python, Java, Kotlin, Go, C#, WebAssembly/JavaScript, Rust.

**iOS impact:** The Paraformer `is_final` flag is now controlled through SetOption rather than a direct property. Existing code using `is_final` directly should migrate to `stream.SetOption("is_final", "1")`.

### Memory Session Options via Config (v1.12.39)
ONNX Runtime session memory options (arena allocator, memory pattern, etc.) are now exposed through the model config structs, allowing fine-grained control over memory usage on memory-constrained devices such as iPhones.

### Log Probabilities in OfflineRecognizerResult (v1.13.0)
Token-level log probabilities are now exposed in `OfflineRecognizerResult` for Go bindings. (C/Swift exposure is a future step.)

---

## Bug Fixes Relevant to iOS

| Version | Fix |
|---------|-----|
| v1.12.39 | Fix offset-by-one error in Pyannote speaker diarization — affects silence detection accuracy |
| v1.12.39 | Check for nullptr in all C/CXX APIs — prevents crashes when NULL model pointers are passed |
| v1.12.35 | Fix C API for reading multi-channel WAV files — critical for stereo microphone input |
| v1.12.30  | Fix bugs in CXX APIs (return value handling in several recognition paths) |
| v1.12.35 | Remove num_threads assertion from OnlineRecognizer — allows 0 threads (auto) without crash |
| v1.12.31 | Fix Swift tests — test suite now passes cleanly on Apple platforms |
| v1.12.31 | Fix TTS deprecated warnings — removes Xcode deprecation noise in TTS Swift wrappers |

---

## Dependency Updates

| Dependency | Before | After | Notes |
|-----------|--------|-------|-------|
| ONNX Runtime (iOS xcframework) | **1.17.1** | **1.25.1** | Upgraded from Microsoft official static xcframework |
| ONNX Runtime (CMake / macOS) | ~1.17.x | **1.24.4** | v1.12.38 (#3501). macOS/Mac Catalyst auto-downloaded by CMake |
| Eigen | v3.x | **v5.0.1** | v1.12.39 (#3505) |
| OpenFST | v1.8.x | **v1.8.5** | v1.12.37 (#3495), with compiler warning fixes |
| onnxruntime (Android) | v1.23.2 | v1.24.3/4 | Android-only |

---

## TTS Engine Internal Refactoring (v1.12.31)

Kokoro, Matcha, VITS, and KittenTTS TTS engines have been refactored to use a new unified `Generate` API internally. This is a non-breaking internal change — the public Swift/C APIs are unchanged, but the refactoring improves code consistency and will make adding new TTS models easier in the future.

---

## Build Script Changes (`build-ios.sh`)

The upstream `build-ios.sh` (called by our custom `build-xcframework.sh`) received one notable change in v1.12.37:

- **Added** `-DSHERPA_ONNX_ENABLE_BINARY=OFF` to all three cmake configurations (simulator x86_64, simulator arm64, and device arm64). This prevents building unnecessary binary executables during the iOS library build, reducing build time.
- **Removed** `--verbose` from all `cmake --build` commands (reduces log noise).

**Our custom `build-xcframework.sh` wrapper requires no changes** — it calls `build-ios.sh`, `build-swift-macos.sh`, and `build-maccatalyst.sh` sub-scripts, and the wrapper logic for merging xcframeworks is unaffected by the upstream changes.

> **Recommended future improvement:** The iOS pre-built ONNX Runtime xcframework in `build-ios.sh` is still pinned to `v1.17.1`. The main CMake build now uses v1.24.4. Consider upgrading `onnxruntime_version` in `build-ios.sh` once a v1.24.x xcframework is available from `csukuangfj/onnxruntime-libs`.

---

## Risk Assessment

| Area | Risk | Notes |
|------|------|-------|
| Existing TTS (Kokoro, VITS, Matcha) | **Low** | Internal refactor only; public API unchanged |
| Existing ASR (Paraformer, Transducer, Whisper) | **Low–Medium** | Paraformer `is_final` migrated to SetOption; check if used directly |
| New TTS models (Supertonic, ZipVoice) | **Low** | Additive only; require new bindings in `sherpa-onnx_swift` before use |
| New ASR models (Qwen3, Cohere, Moonshine v2) | **Low** | Additive; need new Swift bindings before use |
| Source separation / speech denoising | **Low** | Entirely new feature category; no existing code affected |
| ONNX Runtime v1.24.4 | **Low** | iOS build still uses v1.17.1 xcframework; only affects macOS/Mac Catalyst CMake builds |
| Pyannote diarization fix | **Low** | Correctness fix only; silence segmentation improves slightly |
| C API nullptr check | **Low** | Defensive hardening; eliminates a crash class on invalid configs |
| Multi-channel WAV fix | **Low–Medium** | If stereo WAV input is used, previous results may differ slightly |
| OpenFST v1.8.5 / Eigen v5.0.1 | **Low** | Build-time only; no API changes |
| **Overall** | **Low** | Mostly additive. Verify Paraformer `is_final` usage if present. |
