//
//  ViewModel.swift
//  SherpaOnnxTts
//
//  Created by fangjun on 2023/11/23.
//

import Foundation

// used to get the path to espeak-ng-data
func resourceURL(to path: String) -> String {
  return URL(string: "kokoro-82m/\(path)", relativeTo: Bundle.main.resourceURL)!.path
}

func getResource(_ forResource: String, _ ofType: String) -> String {
  let path = Bundle.main.path(forResource: "kokoro-82m/\(forResource)", ofType: ofType)
  precondition(
    path != nil,
    "\(forResource).\(ofType) does not exist!\n" + "Remember to change \n"
      + "  Build Phases -> Copy Bundle Resources\n" + "to add it!"
  )
  return path!
}

/// Please refer to
/// https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/index.html
/// to download pre-trained models

func getTtsForVCTK() -> SherpaOnnxOfflineTtsWrapper {
  // See the following link
  // https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/vits.html#vctk-english-multi-speaker-109-speakers

  // vits-vctk.onnx
  let model = getResource("vits-vctk", "onnx")

  // lexicon.txt
  let lexicon = getResource("lexicon", "txt")

  // tokens.txt
  let tokens = getResource("tokens", "txt")

  let vits = sherpaOnnxOfflineTtsVitsModelConfig(model: model, lexicon: lexicon, tokens: tokens)
  let modelConfig = sherpaOnnxOfflineTtsModelConfig(vits: vits)
  var config = sherpaOnnxOfflineTtsConfig(model: modelConfig)
  return SherpaOnnxOfflineTtsWrapper(config: &config)
}

func getTtsForAishell3() -> SherpaOnnxOfflineTtsWrapper {
  // See the following link
  // https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/vits.html#vits-model-aishell3

  let model = getResource("model", "onnx")

  // lexicon.txt
  let lexicon = getResource("lexicon", "txt")

  // tokens.txt
  let tokens = getResource("tokens", "txt")

  // rule.fst
  let ruleFsts = getResource("rule", "fst")

  // rule.far
  let ruleFars = getResource("rule", "far")

  let vits = sherpaOnnxOfflineTtsVitsModelConfig(model: model, lexicon: lexicon, tokens: tokens)
  let modelConfig = sherpaOnnxOfflineTtsModelConfig(vits: vits)
  var config = sherpaOnnxOfflineTtsConfig(
    model: modelConfig,
    ruleFsts: ruleFsts,
    ruleFars: ruleFars
  )
  return SherpaOnnxOfflineTtsWrapper(config: &config)
}

// https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models
func getTtsFor_en_US_amy_low() -> SherpaOnnxOfflineTtsWrapper {
  // please see  https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-amy-low.tar.bz2

  let model = getResource("en_US-amy-low", "onnx")

  // tokens.txt
  let tokens = getResource("tokens", "txt")

  // in this case, we don't need lexicon.txt
  let dataDir = resourceURL(to: "espeak-ng-data")

  let vits = sherpaOnnxOfflineTtsVitsModelConfig(
    model: model, lexicon: "", tokens: tokens, dataDir: dataDir)
  let modelConfig = sherpaOnnxOfflineTtsModelConfig(vits: vits)
  var config = sherpaOnnxOfflineTtsConfig(model: modelConfig)

  return SherpaOnnxOfflineTtsWrapper(config: &config)
}

// https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/vits.html#vits-melo-tts-zh-en-chinese-english-1-speaker
func getTtsFor_zh_en_melo_tts() -> SherpaOnnxOfflineTtsWrapper {
  // please see https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-melo-tts-zh_en.tar.bz2

  let model = getResource("model", "onnx")

  let tokens = getResource("tokens", "txt")
  let lexicon = getResource("lexicon", "txt")

  let numFst = getResource("number", "fst")
  let dateFst = getResource("date", "fst")
  let phoneFst = getResource("phone", "fst")
  let ruleFsts = "\(dateFst),\(phoneFst),\(numFst)"

  let vits = sherpaOnnxOfflineTtsVitsModelConfig(
    model: model, lexicon: lexicon, tokens: tokens,
    dataDir: "",
    noiseScale: 0.667,
    noiseScaleW: 0.8,
    lengthScale: 1.0
  )

  let modelConfig = sherpaOnnxOfflineTtsModelConfig(vits: vits)
  var config = sherpaOnnxOfflineTtsConfig(
    model: modelConfig,
    ruleFsts: ruleFsts
  )

  return SherpaOnnxOfflineTtsWrapper(config: &config)
}

func getTtsFor_matcha_icefall_zh_baker() -> SherpaOnnxOfflineTtsWrapper {
  // please see https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/matcha.html#matcha-icefall-zh-baker-chinese-1-female-speaker

  let acousticModel = getResource("model-steps-3", "onnx")
  let vocoder = getResource("vocos-22khz-univ", "onnx")

  let tokens = getResource("tokens", "txt")
  let lexicon = getResource("lexicon", "txt")

  let numFst = getResource("number", "fst")
  let dateFst = getResource("date", "fst")
  let phoneFst = getResource("phone", "fst")
  let ruleFsts = "\(dateFst),\(phoneFst),\(numFst)"

  let matcha = sherpaOnnxOfflineTtsMatchaModelConfig(
    acousticModel: acousticModel,
    vocoder: vocoder,
    lexicon: lexicon,
    tokens: tokens
  )

  let modelConfig = sherpaOnnxOfflineTtsModelConfig(matcha: matcha)
  var config = sherpaOnnxOfflineTtsConfig(
    model: modelConfig,
    ruleFsts: ruleFsts
  )

  return SherpaOnnxOfflineTtsWrapper(config: &config)
}

func getTtsFor_kokoro_en_v0_19() -> SherpaOnnxOfflineTtsWrapper {
  // please see https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html#kokoro-en-v0-19-english-11-speakers

  let model = getResource("model", "onnx")
  let voices = getResource("voices", "bin")

  // tokens.txt
  let tokens = getResource("tokens", "txt")

  // in this case, we don't need lexicon.txt
  let dataDir = resourceURL(to: "espeak-ng-data")

  let kokoro = sherpaOnnxOfflineTtsKokoroModelConfig(
    model: model, voices: voices, tokens: tokens, dataDir: dataDir)
  let modelConfig = sherpaOnnxOfflineTtsModelConfig(kokoro: kokoro)
  var config = sherpaOnnxOfflineTtsConfig(model: modelConfig)

  return SherpaOnnxOfflineTtsWrapper(config: &config)
}

func getTtsFor_kokoro_multi_lang_v1_0() -> SherpaOnnxOfflineTtsWrapper {
  // please see https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html

  let model = getResource("model", "onnx")
  let voices = getResource("voices", "bin")

  // tokens.txt
  let tokens = getResource("tokens", "txt")

  let lexicon_en = getResource("lexicon-us-en", "txt")
  let lexicon_zh = getResource("lexicon-zh", "txt")
  let lexicon = "\(lexicon_en),\(lexicon_zh)"

  // in this case, we don't need lexicon.txt
  let dataDir = resourceURL(to: "espeak-ng-data")
  let dictDir = resourceURL(to: "dict")

  let numFst = getResource("number-zh", "fst")
  let dateFst = getResource("date-zh", "fst")
  let phoneFst = getResource("phone-zh", "fst")
  let ruleFsts = "\(dateFst),\(phoneFst),\(numFst)"

  let kokoro = sherpaOnnxOfflineTtsKokoroModelConfig(
    model: model, voices: voices, tokens: tokens, dataDir: dataDir,
    dictDir: dictDir, lexicon: lexicon)

  // Force CPU execution to avoid CoreML/provider mismatches on Apple targets.
  let modelConfig = sherpaOnnxOfflineTtsModelConfig(
    vits: sherpaOnnxOfflineTtsVitsModelConfig(),
    matcha: sherpaOnnxOfflineTtsMatchaModelConfig(),
    kokoro: kokoro,
    numThreads: 1,
    debug: 1,
    provider: "cpu"
  )
  var config = sherpaOnnxOfflineTtsConfig(model: modelConfig)

  return SherpaOnnxOfflineTtsWrapper(config: &config)
}

// INT8 Quantized Kokoro Model Configuration
// Based on ONNX Runtime INT8 quantization best practices for CPU targets
func getTtsFor_kokoro_int8_multi_lang_v1_1() -> SherpaOnnxOfflineTtsWrapper {
  // INT8 quantized model: 114MB vs 326MB (65% smaller)
  // Requires specific configuration for stable quantized inference
  
  print("Attempting to load INT8 Kokoro model...")
  
  // CRITICAL: Must use model.int8.onnx for quantized version
  let model = getResource("model.int8", "onnx")
  print("INT8 model path: \(model)")
  
  // Verify model file exists and has reasonable size for INT8 model
  let modelURL = URL(fileURLWithPath: model)
  if let fileSize = try? modelURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
    print("INT8 model file size: \(fileSize) bytes (\(fileSize / 1024 / 1024) MB)")
    if fileSize < 50_000_000 { // Less than 50MB seems too small for Kokoro
      print("WARNING: Model file seems unusually small for Kokoro INT8 model")
    }
  } else {
    print("ERROR: Could not get model file size - file may not exist or be accessible")
  }
  
  let voices = getResource("voices", "bin")
  let tokens = getResource("tokens", "txt")

  let lexicon_en = getResource("lexicon-us-en", "txt")
  let lexicon_zh = getResource("lexicon-zh", "txt")
  let lexicon = "\(lexicon_en),\(lexicon_zh)"

  let dataDir = resourceURL(to: "espeak-ng-data")
  let dictDir = resourceURL(to: "dict")

  let numFst = getResource("number-zh", "fst")
  let dateFst = getResource("date-zh", "fst")
  let phoneFst = getResource("phone-zh", "fst")
  let ruleFsts = "\(dateFst),\(phoneFst),\(numFst)"

  let kokoro = sherpaOnnxOfflineTtsKokoroModelConfig(
    model: model, voices: voices, tokens: tokens, dataDir: dataDir,
    dictDir: dictDir, lexicon: lexicon)
  
  // CRITICAL INT8 Configuration (based on ONNX Runtime quantization docs):
  // 1. Single thread: INT8 operations need sequential execution to prevent races
  // 2. CPU provider: CoreML/hardware accelerators don't support INT8 properly on iOS
  // 3. Debug enabled: Essential for monitoring quantized model behavior
  let modelConfig = sherpaOnnxOfflineTtsModelConfig(
    vits: sherpaOnnxOfflineTtsVitsModelConfig(),
    matcha: sherpaOnnxOfflineTtsMatchaModelConfig(),
    kokoro: kokoro,
    numThreads: 1,     // REQUIRED: Single-threaded for INT8 stability
    debug: 1,          // RECOMMENDED: Debug logging for quantization issues
    provider: "cpu"    // REQUIRED: CPU provider only for INT8 on iOS
  )
  
  var config = sherpaOnnxOfflineTtsConfig(
    model: modelConfig,
    ruleFsts: ruleFsts  // Include rule FSTs for proper text normalization
  )
  
  print("Loading INT8 Kokoro model (114MB) - optimized for CPU inference")
  let ttsWrapper = SherpaOnnxOfflineTtsWrapper(config: &config)
  print("INT8 TTS wrapper created successfully")
  return ttsWrapper
}

func createOfflineTts() -> SherpaOnnxOfflineTtsWrapper {
  // Please enable only one of them
  
  // OPTION 1: Regular Kokoro model (326MB, very reliable)
   return getTtsFor_kokoro_multi_lang_v1_0()
  
  // OPTION 2: INT8 Quantized Kokoro model (114MB, smaller but needs proper config)
  // return getTtsFor_kokoro_int8_multi_lang_v1_1()

  // return getTtsFor_kokoro_en_v0_19()

  // return getTtsFor_matcha_icefall_zh_baker()

  // return getTtsFor_en_US_amy_low()

  // return getTtsForVCTK()

  // return getTtsForAishell3()

  // return getTtsFor_zh_en_melo_tts()

  // please add more models on need by following the above two examples
}
