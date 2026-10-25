# sherpa-onnx: What's New (v1.13.0 → v2.0.0)

**Merged:** 2026-10-24 · **Upstream:** https://github.com/k2-fsa/sherpa-onnx master (255 commits, v1.13.0..v2.0.0; fork merge `f628b38c`)
**Integration doc:** `helper/docs/sherpa-onnx_build.md`, `helper/docs/sherpa-onnx_swift_implementation.md`, `helper/docs/audio_tts.md` § SherpaONNX
**Consumers:** `thirdparty/sherpa-onnx_swift` (bridge, branch `release/v2.0.0`), `libs/audio/sherpa/` (Kokoro speaker + Swift frontend), the sherpa ASR/VAD paths

255 upstream commits. The one item that matters for us is **#4055: espeak-ng and piper-phonemize are gone**.
v2.0.0 ships no GPL code, which is why we take it, but espeak was what pronounced every Kokoro word the
lexicon files do not list and every digit. Taken as-is, v2.0.0 still loads and speaks, yet silently skips
those words: the probe measured **0 OOV recall and 0 number recall on all 6 voices**. That was a silent
ship-blocker. It is closed app-side by a Swift Kokoro frontend (normalizer, lexicon, BART G2P, letter names)
that feeds phoneme tokens through the new v2 `GenerationConfig` API. The tokens path also has no length
split and can `SHERPA_ONNX_EXIT` the app (R1), so the bridge caps token runs. Plan:
`helper/plans/sherpa-v2-kokoro-swift-frontend.md` (moved to `helper/docs/plans/` at commit).

---

## 1. Changes
| Commit / PR | What changed | Reaches the app? |
|---|---|---|
| #4055 `0b364763` | Remove espeak-ng and piper-phonemize. Kokoro gets a lexicon-only text frontend; `data_dir`, `lang`, `dict_dir` are ignored (a warning each). Adds `GenerationConfig.tokens` / `phoneme_codepoints` (+ lengths) | Yes: the reason for the Swift frontend and the bridge port |
| #4075 `ce949db9` | Lexicon TTS: word boundaries, OOV words, Unicode handling | Yes (zh text path; logs "OOV word skipped") |
| #3935 `bf690ea1` (#3718, #3861 before it) | onnxruntime 1.27.0 → 1.27.1 → 1.28.2 | Yes: every sherpa model (TTS, ASR, VAD) |
| #3816 / #3831 / #3833 | SPM support; xcframework build refactor (`build-macos.sh`, SherpaOnnxC.framework); static ORT in the xcframework | No: the fork keeps its own `build-ios.sh` / `build-swift-macos.sh` layout (§3) |
| #3820 `e20193a0` | Validate the Kokoro voices file | Yes (init error instead of a bad read) |
| #3781 `29d77d2c` | Fix use-after-free in async TTS progress callbacks | No (the bridge passes no callback) |
| #3749 `d826b7e6` | Do not abort when espeak rejects the voice | Moot after #4055 |
| #3881 / #3936 | Per-segment confidence in offline speaker diarization | ABI only (struct field mirrored) |
| #4018, #3965, #3920 | Offline CTC timestamps, byte-level BPE char loss (whisper/cohere), Canary empty transcript | Only if those ASR models are used |
| #3954, #3898, #3933, #3928 | Kokoro distills (7M ar/en), Nabra Arabic Kokoro, em_santa voice | No (catalogue candidates, §6) |

## 2. Public API
| Symbol | Change | Our usage / fix |
|---|---|---|
| `SherpaOnnxGenerationConfig` | +`tokens`, `num_tokens`, `phoneme_codepoints`, `num_phoneme_codepoints` and per-sentence lengths (6 fields) | Ported as `SherpaOnnxGenerationConfigSwift` / `SherpaOnnxGenerationConfigC` + `generateWithConfig` in `Sources/SherpaOnnx.swift`. Every C pointer lives in an owned heap buffer freed in `deinit` (upstream's Swift example keeps pointers from `withUnsafeBufferPointer` past the closure: undefined behaviour) |
| `SherpaOnnxOfflineTtsKokoroModelConfig.data_dir`, `.lang`, `.dict_dir` | Deprecated, ignored, warn | The bridge passes `""` for all; `loadModelPaths` no longer requires `espeak-ng-data/phontab` |
| `OfflineRecognizerConfig` | +`ctc_fst_decoder_config` | Mirrored (default 0 = off) |
| `OfflineTtsKittenModelConfig` | +`lexicon` | Mirrored |
| `OfflineSpeakerSegmentationPyannoteModelConfig` / `FastClusteringConfig` / `OfflineSpeakerDiarizationSegment` | +`window_shift_ratio` / +`compute_confidence` / +`confidence` | Mirrored; defaults 0 |
| `OfflineSpeechDenoiserDpdfNetModelConfig` | +`attenuation_limit_db` | Mirrored |
| `SpeechSegment.start`, `CircularBufferGet` start, `CircularBufferHead` | int32 → int64 | `Int64(startIndex)` at the call |
| Diacritization*, `OfflineTtsLang`, `SpeakerEmbeddingManagerDim/GetEmbedding`, `GetOnnxruntimeVersionStr` | New | Not wrapped (no consumer) |

Bridge (`thirdparty/sherpa-onnx_swift`, all marked `wangqi modified 2026-10-24`):
`SynthesisSegment` (`.text` / `.tokens`) and `InputResolver`; `synthesize(segments:speakerId:)`;
**one shared engine per config** (weak registry, created inside `registryLock`, `prepareEngine()`,
`isEngineResident(for:)`) replacing the per-call `SherpaOnnxOfflineTts` rebuild; `capTokenRuns` (R1);
`smartChunkText` no longer cuts at every `.` (`$42.50`, `3.14`, `Dr. Smith`, `p.m.` stay whole);
`Task.checkCancellation()` per export chunk; `loadModelPaths(modelRootDir:)` with the v2 Kokoro config
(lexicons us-en + zh, FSTs phone, date, number in upstream order, no espeak, empty `dataDir` / `lang`);
a NULL engine now throws `initializationFailed`.

App (`libs/audio/sherpa/`): `SherpaKokoroTextNormalizer` (numbers, dates, times, money, phones,
ordinals, abbreviations; en-US / en-GB), `SherpaKokoroFrontend` (voice-language routing, lexicon
us/gb, zh segment mixing), `SherpaKokoroBARTG2P` (Core ML BART port of FluidAudio `G2PModel`, Apache-2.0),
`CoreAIKokoroG2P` gains a dictionary init and an OOV hook (shared with the Core AI Kokoro engine).

## 3. Conflicts and fork patches
| File | Resolution |
|---|---|
| `build-ios.sh` | Upstream body (ORT `${SHERPA_ONNX_ONNXRUNTIME_VERSION:-1.28.2}`, framework-style lib/include dirs) + the fork's pinned SDK / clang / libtool block. Tail kept in the fork's lib + Headers layout (`build-xcframework.sh` and the bridge's `CSherpaOnnx` symlink read `ios-arm64/Headers/sherpa-onnx`). Library list = v2 (no ucd / piper / espeak, + utf8proc). The compat-device / compat-sim symlinks were dropped: v2's cmake finds `onnxruntime.framework` itself |
| `build-swift-macos.sh` (deleted upstream, #3831) | **Kept**: `build-xcframework.sh` needs its `libsherpa-onnx.a` and `libonnxruntime.a`. Library list set to v2 |
| `build-maccatalyst.sh`, `build-xcframework.sh` | ORT 1.28.2; v2 library list |
| 3 sample apps (SherpaOnnxAsr `ViewController.swift`, TtsLexicon `ViewModel.swift`, TtsPhonemize `project.pbxproj`) | No fork commit touched them: taken from v2.0.0 |
| SherpaOnnxTts `ContentView.swift` + 2 xcschemes | Deleted upstream (espeak sample): removed |

Patch inventory: v1.13.0 fork had 0 `wangqi modified` tags; the real patch list (`v1.13.0..39437ad2`:
ORT / SDK pinning, Catalyst build, macOS ORT slice in the xcframework) is all kept. Tree tags now:
`build-ios.sh` 7, `build-swift-macos.sh` 4, `build-maccatalyst.sh` 3, `build-xcframework.sh` 1. Bridge:
`SherpaONNXTTSManager.swift` 16, `SherpaOnnx.swift` 11, `Package.swift` 2.

## 4. Dependencies
onnxruntime **1.25.1 (iOS) / 1.24.4 (macOS, Catalyst) → 1.28.2 everywhere** (upstream #3935). iOS,
macOS and Catalyst now link the same ORT, which was not true before. `sherpa-onnx_swift/Package.swift`
points its onnxruntime binaryTarget at `ios-onnxruntime/1.28.2/`. The bridge's vendored COnnxRuntime
headers are still ORT API 17; only `import` is used (pre-existing mismatch, left as is). No other move.

## 5. Risk assessment — 5 risks (1 H, 3 M, 1 L)
### R1 — the tokens path has no length split and EXITs the process (HIGH)
**Problem:** `offline-tts-kokoro-impl.h` re-splits tokens only at `, . ! ? ; :`; a piece of 510+ tokens
reaches `OfflineTtsKokoroModel::Run`, which calls `SHERPA_ONNX_EXIT(-1)` and kills the app.
**Verify:** `SherpaKokoroTokenCapTests`; `SherpaKokoroEngineTests` (a 1500-token single run does not kill
the host). **Status:** fixed by `capTokenRuns` (runs ≤ 400, `,` inserted before a space), verified.
### R2 — silent loss of OOV words and digits (MEDIUM, was a ship-blocker)
**Problem:** #4055; no error, just skipped words. **Verify:** `run_sherpa_tests.py --compare
sherpa-20261024-185644.json` (OOV and number recall per voice). **Status:** Swift frontend; see §8.
### R3 — engine residency vs the one-local-model rule (MEDIUM)
**Problem:** the cached engine (~630 MB measured, §8) stays resident while a speaker holds it. `numThreads` is in
the engine key, so TTSConv export (`exportThreadCount`, usually 4) and chat TTS (2) use separate engines that evict
each other, as in v1.13. **Verify:**
`SherpaKokoroEngineTests` (drop every manager → not resident); device check of the
`willLoadAudioModel` skip. **Status:** other text / audio / image loads still unload every sherpa speaker.
### R4 — stale `data/kokoro-82M` in a building checkout (MEDIUM)
**Problem:** `data/kokoro-82M` is git-ignored; a checkout without `g2p/` ships spelled OOV words, one
with `espeak-ng-data/` ships dead GPL data. **Verify:** `check_archive_kokoro_bundle` in
`appstore_deploy.sh` (fails the archive). **Status:** tested on a fake archive; main checkout updated at commit.
### R5 — onnxruntime 1.28.2 numerical drift on other sherpa models (LOW)
**Verify:** `PPDocLayoutPostprocessTests`, `GLiNERPIIDetectorTests`, `GLiNERPIIDetectorMultilingualTests`,
`PrivacyDetectorTests` (one standing failure, `testNEROverTriggersOnNameDenseBusinessEmail`). **Status:** §8.

## 6. New models
| Model | Size / params | Decision | Reason |
|---|---|---|---|
| Kokoro 7M distills (ar / en, #3954) | 7M | Not now | English quality below the 82M we ship; no Arabic TTS consumer |
| Nabra-82M Arabic Kokoro (#3898, #3933) | 82M | Not now | No Arabic TTS request |
| Kokoro v1.0 `em_santa` voice (#3928) | voice only | Not now | Seasonal |
| Kokoro v1.1-zh | 82M | Out of scope | Separate study |

## 7. Opportunities (not built)
| Upstream feature | Consumer that would use it | Value |
|---|---|---|
| `GenerationConfig.phoneme_codepoints` | VITS / Piper / Matcha / Melo (now need pre-phonemized input) | Would revive those engines without espeak, via the same Swift frontend |
| `GetOnnxruntimeVersionStr` | Settings > Local AI > About | Shows the linked ORT version |
| Diarization per-segment confidence | Meetings speaker labels | Flag uncertain speaker turns |

## 8. Verification
Commands and logs: plan `## Verification` (Part 1-5 targeted + full regression set);
logs in `/Volumes/ssd2t/modeltests/thirdparty-upgrade/run-20261024/sherpa/devflow/`, results in its
`results.txt`. Probe: `RUN_TESTS_SLOT=9 SHERPATEST_MODEL_DIR=/Volumes/ssd2t/modeltests/sherpa-stage/kokoro-82M-v2
./with_test_slot.sh ./run_sherpa_tests.py --force-build --compare /Volumes/ssd2t/modeltests/reports/sherpa-20261024-185644.json`
(6 voices x 6 sentences + 1 report-only paragraph row; baseline = v1.13.0 with espeak, 6/0/0);
the new report is `/Volumes/ssd2t/modeltests/reports/sherpa-<stamp>.json`.
Unit suites (slot 9): `SherpaKokoroTokenCapTests`, `SherpaSmartChunkTextTests`, `SherpaKokoroModelPathsTests`,
`SherpaKokoroTextNormalizerTests`, `SherpaKokoroFrontendTests`, `CoreAIKokoroG2PTests`,
`SherpaKokoroBARTG2PTests`, `SherpaKokoroEngineTests` (green at Parts 1-4) plus the regression guards.
App builds: AIAssistant (iPhone 18 Pro Max simulator) and AIAssistantMac green at Part 4.
Final probe (after the change-review fixes) `sherpa-20261024-235524.json` vs v1.13.0 `sherpa-20261024-185644.json`
(v1.13 values as stored in its report; `--compare` rescores the baseline with the current yardstick, which lifts the
zh number baseline to 0.429). The pre-review run `sherpa-20261024-224923.json` had no REGRESSED.

| Voice | sim v1.13 -> v2 | OOV v1.13 -> v2 | number v1.13 -> v2 | first audio (s) | engine (MB) |
|---|---|---|---|---|---|
| en-us-heart | 0.799 -> 0.782 | 1.0 -> 0.9 (within band) | 0.571 -> 0.714 | 4.65 | 486.9 |
| en-us-adam | 0.767 -> 0.816 | 0.9 -> 0.9 | 0.714 -> 0.857 | 3.18 | 630.8 |
| en-gb-alice | 0.674 -> 0.734 | 0.625 -> 0.75 | 0.0 -> 0.286 | 4.50 | 634.8 |
| en-gb-daniel | 0.655 -> 0.775 | 0.625 -> 0.75 | 0.0 -> 0.714 | 4.26 | 632.1 |
| zh-xiaobei | 0.497 -> 0.594 | 0.5 -> 0.0 (flagged, see below) | 0.429 -> 1.0 | 3.73 | 628.3 |
| zh-yunxi | 0.59 -> 0.591 | 0.0 -> 0.5 | 0.429 -> 1.0 | 3.39 | 631.5 |

**zh-xiaobei REGRESSED (OOV 0.5 -> 0.0) reviewed as a judge-orthography false positive, not a TTS regression.**
Each zh voice has only two OOV words (Velkaro, Tamberlune), so one word is a 0.5 step against a 0.10 band. Velkaro
was missed by every run, v1.13 included for yunxi. Tamberlune: the pre-review run transcribed xiaobei as
"Timberline" (difflib 0.80, counted), this run as "Timberloon" (0.70, under OOV_MATCH_RATIO 0.75), which is the
closer reading of "-lune"; yunxi moved the other way on the same word ("Denver" -> "Timberlane", 0.80). No threshold
was changed. A larger zh OOV pool in the corpus would remove the 0.5 step (follow-up).

Engine ~626-642 MB resident (`phys_footprint` growth across `prepareEngine()`), engine load 0.6-1.1 s.
Regression suite (`p6-results.txt`, the post-review re-run; iOS + Mac builds exit 0, Package.resolved unchanged): SherpaKokoroTextNormalizerTests,
SherpaKokoroTokenCapTests, SherpaSmartChunkTextTests, SherpaKokoroModelPathsTests, SherpaKokoroFrontendTests,
SherpaKokoroBARTG2PTests, SherpaKokoroEngineTests, CoreAIKokoroG2PTests, CoreAIKokoroHostDSPTests,
TTSSettingsOverrideTests, TTSTextChunkerTests, TTSConvSpecCodableTests, LocalModelAboutEngineInfoTests,
ICloudAccessAuditTests, PPDocLayoutPostprocessTests, GLiNERPIIDetectorTests, GLiNERPIIDetectorMultilingualTests,
PrivacyDetectorTests: all green except the standing
`PrivacyDetectorTests.testNEROverTriggersOnNameDenseBusinessEmail` (unrelated, red before this change).
**Not verifiable on macOS:** first speak latency and memory on a device, the `willLoadAudioModel` skip
between two speakers on the same engine key (and eviction when the thread counts differ), `CoreAIKokoroSpeakerTests` (device-only).
