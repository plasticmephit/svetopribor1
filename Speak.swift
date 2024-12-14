//
//  Speak.swift
//  svetopribor
//
//  Created by Maksimilian on 6.02.23.
//

import Foundation
import AVFAudio

class Speak {

    let voices = AVSpeechSynthesisVoice.speechVoices()
    let voiceSynth = AVSpeechSynthesizer()
    var voiceToUse: AVSpeechSynthesisVoice?

  init(){
    for voice in voices {
        if voice.quality == .enhanced {
        voiceToUse = voice
      }
    }
  }

    func sayThis(_ phrase: String){
        voiceSynth.stopSpeaking(at: .immediate)
      let utterance = AVSpeechUtterance(string: phrase)
          utterance.voice = voiceToUse
          utterance.rate = 0.5

        voiceSynth.speak(utterance)
    }
}
