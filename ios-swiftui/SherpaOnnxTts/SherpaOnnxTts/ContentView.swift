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

    private var tts = createOfflineTts()

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
                    let speakerId = Int(self.sid) ?? 0
                    let t = self.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if t.isEmpty {
                        self.showAlert = true
                        return
                    }

                    // CRITICAL FIX: Setup AVAudioSession for iOS
                    do {
                        let audioSession = AVAudioSession.sharedInstance()
                        try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                        try audioSession.setActive(true)
                        print("Audio session configured successfully")
                    } catch {
                        print("Failed to setup audio session: \(error)")
                        return
                    }

                    let audio = tts.generate(text: t, sid: speakerId, speed: Float(self.speed))
                    if self.filename.absoluteString.isEmpty {
                        let tempDirectoryURL = NSURL.fileURL(withPath: NSTemporaryDirectory(), isDirectory: true)
                        self.filename = tempDirectoryURL.appendingPathComponent("test.wav")
                    }

                    let success = audio.save(filename: filename.path)
                    guard success == 1 else {
                        print("Failed to save audio file")
                        return
                    }
                    
                    // Debug logging
                    print("Audio file saved to: \(filename.path)")
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: filename.path),
                       let fileSize = attrs[.size] as? Int64 {
                        print("Audio file size: \(fileSize) bytes")
                    }

                    do {
                        self.audioPlayer = try AVAudioPlayer(contentsOf: filename)
                        
                        // Additional iOS-specific configuration
                        self.audioPlayer.volume = 1.0
                        
                        // Prepare and play
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
                }) {
                    Text("Generate")
                }.alert(isPresented: $showAlert) {
                    Alert(title: Text("Empty text"), message: Text("Please input your text before clicking the Generate button"))
                }
                Spacer()
                Button (action: {
                    // Ensure audio session is active for Play button too
                    do {
                        let audioSession = AVAudioSession.sharedInstance()
                        try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                        try audioSession.setActive(true)
                    } catch {
                        print("Failed to setup audio session for playback: \(error)")
                        return
                    }
                    
                    self.audioPlayer.play()
                }) {
                    Text("Play")
                }.disabled(filename.absoluteString.isEmpty)
                Spacer()
            }
            Spacer()
        }
        .padding()
    }
}
