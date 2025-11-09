# sherpa-onnx – November 2025 refresh

The `integrate/local-changes` branch now tracks upstream `k2-fsa/sherpa-onnx` at commit `e4f48ce` plus the local iOS/macOS integration work from autumn 2025. This document highlights the notable additions, platform-specific upgrades, and risks introduced by the current sync.

## New
- **ZipVoice zero‑shot TTS** – the C API now exposes `SherpaOnnxOfflineTtsZipvoiceModelConfig`, enabling text‑encoder + flow‑matching + vocoder pipelines with guidance and RMS controls. Swift glue in `thirdparty/sherpa-onnx_swift` can construct the new config (tokens, text model, flow‑matching model, `pinyin_dict`, etc.) and route it through `SherpaOnnxOfflineTtsModelConfig`.
- **Tone/T-one CTC streaming ASR** – online model configs gained a dedicated `t_one_ctc` slot. Swift wrappers were updated so iOS code can load the new Chinese tone-aware checkpoints without editing generated headers.
- **Wenet CTC offline models** – offline recognizer configs include a `wenet_ctc` field, allowing direct use of community WeNet checkpoints in C/Swift bindings.
- **XCFramework merger pipeline** – new `build-xcframework.sh` collects the freshly built iOS (device + simulator) and macOS static archives into `build-apple/sherpa-onnx.xcframework`, simplifying reuse inside `aiassistant`.
- **Merge-prep automation** – `git_prepare_merge.sh` snapshots the fork, hard-syncs `master` with upstream, exports conflict metadata, and leaves the repo ready for manual conflict resolution.

## Improvements
- **iOS/macOS build reproducibility** – `build-ios.sh` now queries `xcrun` for SDK and toolchain paths, guaranteeing the correct (26.1) SDK even when Xcode upgrades. Explicit `clang`/`clang++`/`libtool` paths eliminate the “compiler not found” and `-static` link failures seen on Apple Silicon.
- **SwiftUI TTS sample hardening** – `ContentView.swift` and `ViewModel.swift` now:
  - create a fresh `SherpaOnnxOfflineTtsWrapper` for each synthesis, guard against empty text, and perform generation on a background queue;
  - persist `SherpaOnnxGeneratedAudioWrapper` to avoid premature deallocation;
  - enforce CPU provider / single-threaded execution for Kokoro models and add an INT8 variant with diagnostics (file-size checks, rule FST wiring, etc.);
  - wrap audio session setup and playback state transitions in helper methods with meaningful logging.
- **Xcode project hygiene** – resource folders (e.g., `kokoro-82m`) are covered by file-system synced groups, shared schemes were added for iOS and macOS targets, and `objectVersion` bumped to 70 to align with Xcode 16 toolchains.
- **Repo hygiene** – `.gitignore` now excludes large Kokoro resource folders copied into the SwiftUI sample so checkouts stay lightweight.

## Fixes
- **CPU-only Kokoro path** – forcing `provider: "cpu"` and `numThreads = 1` prevents ONNX Runtime from defaulting to unsupported CoreML accelerators on iOS/macOS, which previously produced empty audio buffers.
- **Crashy concurrent playback** – the SwiftUI demo now serializes generation via `isGenerating`, retains `AVAudioPlayer`, and validates sample energy before saving/playing WAV output, resolving previous crashes when tapping “Generate” repeatedly.
- **SDK drift** – `build-ios.sh` detected the mismatch between legacy iPhoneSimulator18.5 paths and the installed 26.1 SDK; the new script fails fast with clear diagnostics when `xcode-select` points elsewhere.

## Breaking / Risky Changes
- **Massive upstream delta** – `out_prepare_manual_20251109-060454/local_diffstat_vs_upstream.log` shows extensive edits/removals across CI workflows, Android/Flutter/Dart examples, and python/node/go bindings. Downstream automation that referenced removed files (e.g., `export-*-ascend` workflows, Flutter VAD sample) will break unless updated.
- **Xcode 16 requirement** – the updated `.pbxproj` uses `PBXFileSystemSynchronizedBuildFileExceptionSet` and `objectVersion = 70`. Builds on older Xcode releases will fail to parse the project file.
- **Resource handling** – the SwiftUI sample and `.gitignore` expect `ios-swiftui/SherpaOnnxTts/kokoro-82m/…` assets to be restored manually after a clean checkout. Failing to do so results in runtime crashes when the app looks for bundled models.
- **INT8 Kokoro config** – experimental INT8 support introduces strict single-threading and higher logging volume. Running with the wrong ONNX Runtime delegate or missing dict assets can still cause silent output; treat the INT8 path as beta.
- **CI coverage gaps** – many upstream GitHub workflows were deleted or heavily modified. Until replacement pipelines are verified, there is reduced automated test coverage for non-Apple targets.

## Docs / CI / Build
- Removed a large set of specialized workflow files (Ascend/RKNN exporters, Pascal sample builders, etc.) while consolidating others; ensure your fork does not rely on the deleted automation.
- `README.md` and `CHANGELOG.md` were touched but not yet rewritten; use this `whats_new.md` for the current state until an upstream changelog lands.

## Upgrade Notes & Testing Recommendations
1. **Rebuild native artifacts** – run `./build-ios.sh`, `./build-swift-macos.sh`, then `./build-xcframework.sh`. Verify `build-apple/sherpa-onnx.xcframework` contains all three slices before consuming it in `aiassistant`.
2. **Sample validation** – launch `ios-swiftui/SherpaOnnxTts` on device/simulator and test:
   - standard Kokoro multi-lang model,
   - the new INT8 model path,
   - ZipVoice (if assets are available) to ensure the Swift glue passes configs correctly.
3. **Regression sweep** – because CI coverage shrank, manually spot-check at least one ASR (online + offline) and one VAD binary build on macOS/iOS.
4. **Resource packaging** – confirm `.gitignore` exclusions do not hide critical assets in release archives. For xcframework distribution, embed the `kokoro-82m` resources within your main app bundle.

Proceed with caution if downstream scripts referenced deleted workflow files or expect older C API layouts—the new configs (`t_one_ctc`, `wenet_ctc`, `zipvoice`) are required fields in struct initializers now.
