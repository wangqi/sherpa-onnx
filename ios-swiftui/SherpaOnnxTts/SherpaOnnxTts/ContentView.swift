//
//  ContentView.swift
//  SherpaOnnxTts
//
//  Created by fangjun on 2023/11/23.
//
// Text-to-speech with Next-gen Kaldi on iOS without Internet connection

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var sid = "0"
    @State private var speed = 1.0
    @State private var text = ""
    @State private var showAlert = false
    @State var filename: URL = NSURL() as URL
    @State var audioPlayer: AVAudioPlayer!
    
    // CRITICAL FIX: Keep audio objects as instance variables to prevent race condition
    @State private var generatedAudio: SherpaOnnxGeneratedAudioWrapper?
    @State private var isGenerating = false

    // CRITICAL FIX: Don't reuse TTS instance - create fresh one each time

    var body: some View {

        VStack(alignment: .leading) {
            HStack {
                Spacer()
                Text("Next-gen Kaldi: TTS").font(.title)
                Spacer()
            }
            HStack{
                Text("Speaker ID")
                TextField("Please input a speaker ID", text: $sid).textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
            }
            HStack{
                Text("Speed \(String(format: "%.1f", speed))")
                    .padding(.trailing)
                Slider(value: $speed, in: 0.5...2.0, step: 0.1) {
                    Text("Speech speed")
                }
            }

            Text("Please input your text below").padding([.trailing, .top, .bottom])

            TextEditor(text: $text)
                .font(.body)
                .opacity(self.text.isEmpty ? 0.25 : 1)
                .disableAutocorrection(true)
                .border(Color.black)

            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    generateAndPlayAudio()
                }) {
                    Text(isGenerating ? "Generating..." : "Generate")
                }
                .disabled(isGenerating)
                .alert(isPresented: $showAlert) {
                    Alert(title: Text("Empty text"), message: Text("Please input your text before clicking the Generate button"))
                }
                Spacer()
                Button (action: {
                    playStoredAudio()
                }) {
                    Text("Play")
                }.disabled(filename.absoluteString.isEmpty)
                Spacer()
            }
            Spacer()
        }
        .padding()
    }
    
    // CRITICAL FIX: Separate function with proper synchronization
    private func generateAndPlayAudio() {
        let speakerId = Int(self.sid) ?? 0
        let t = self.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            self.showAlert = true
            return
        }
        
        // Prevent multiple concurrent generations
        guard !isGenerating else { return }
        isGenerating = true
        
        // Setup audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
            print("Audio session configured successfully")
        } catch {
            print("Failed to setup audio session: \(error)")
            isGenerating = false
            return
        }
        
        // Use background queue for TTS generation to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            print("Starting TTS generation for: '\(t)' with speaker \(speakerId)")
            
            // CRITICAL FIX: Create fresh TTS instance for each synthesis to avoid session reuse corruption
            let freshTts = createOfflineTts()
            print("Created fresh TTS instance to avoid session reuse issues")
            
            // Generate audio with fresh instance and keep reference alive
            print("Attempting TTS generation with text: '\(t)', speakerId: \(speakerId), speed: \(self.speed)")
            let audio = freshTts.generate(text: t, sid: speakerId, speed: Float(self.speed))
            print("TTS generation completed, checking results...")
            
            // CRITICAL: Store audio object to prevent deallocation
            DispatchQueue.main.async {
                self.generatedAudio = audio
                
                print("Audio generated - samples: \(audio.samples.count), sample rate: \(audio.sampleRate)")
                
                // CRITICAL FIX: Validate audio quality before proceeding
                let nonZeroSamples = audio.samples.filter { abs($0) > 0.001 }.count
                let sampleRatio = Double(nonZeroSamples) / Double(audio.samples.count)
                
                print("Audio validation - Non-zero samples: \(nonZeroSamples)/\(audio.samples.count) (\(String(format: "%.1f", sampleRatio * 100))%)")
                
                if sampleRatio > 0.1 { // At least 10% non-zero samples indicates valid audio
                    print("Audio validation PASSED - proceeding with save and playback")
                    // Proceed with file save and playback
                    self.saveAndPlayAudio(audio: audio)
                } else {
                    print("Audio validation FAILED - generated mostly silent audio, this indicates model inference failure")
                    self.isGenerating = false
                    // Could implement retry logic here in the future
                }
            }
        }
    }
    
    // CRITICAL FIX: Synchronous file save with audio object kept alive
    private func saveAndPlayAudio(audio: SherpaOnnxGeneratedAudioWrapper) {
        // Ensure we have a filename
        if self.filename.absoluteString.isEmpty {
            let tempDirectoryURL = NSURL.fileURL(withPath: NSTemporaryDirectory(), isDirectory: true)
            self.filename = tempDirectoryURL.appendingPathComponent("test.wav")
        }
        
        print("Attempting to save audio to: \(filename.path)")
        
        // CRITICAL: Save audio while keeping reference alive  
        let success = audio.save(filename: filename.path)
        guard success == 1 else {
            print("Failed to save audio file, error code: \(success)")
            isGenerating = false
            return
        }
        
        // Verify file was written correctly
        if let attrs = try? FileManager.default.attributesOfItem(atPath: filename.path),
           let fileSize = attrs[.size] as? Int64 {
            print("Audio file saved successfully: \(fileSize) bytes")
            
            // Additional verification - check if file contains data
            if let data = try? Data(contentsOf: filename) {
                let nonZeroBytes = data.filter { $0 != 0 }.count
                print("File verification - Total bytes: \(data.count), Non-zero bytes: \(nonZeroBytes)")
                
                if nonZeroBytes == 0 {
                    print("WARNING: File contains only zeros despite successful save!")
                }
            }
        } else {
            print("Failed to get file attributes")
        }
        
        // Now play the audio
        playAudioFile()
        
        // Reset generation flag
        isGenerating = false
    }
    
    // CRITICAL FIX: Separate playback function with error handling
    private func playAudioFile() {
        do {
            // Recreate audio player from file
            self.audioPlayer = try AVAudioPlayer(contentsOf: filename)
            self.audioPlayer.volume = 1.0
            
            let prepared = self.audioPlayer.prepareToPlay()
            guard prepared else {
                print("Failed to prepare audio player")
                return
            }
            
            let played = self.audioPlayer.play()
            guard played else {
                print("Failed to start audio playback")
                return
            }
            
            print("Audio playback started successfully")
            print("Audio duration: \(self.audioPlayer.duration) seconds")
            
        } catch {
            print("Failed to create audio player: \(error)")
        }
    }
    
    // Play button function with audio session setup
    private func playStoredAudio() {
        // Ensure audio session is active for Play button too
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session for playback: \(error)")
            return
        }
        
        playAudioFile()
    }
}
