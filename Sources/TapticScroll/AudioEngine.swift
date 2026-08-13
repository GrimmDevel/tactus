import Foundation
import AVFoundation

final class AudioEngine {
    nonisolated(unsafe) static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isSetup = false

    private var nokBuffer: AVAudioPCMBuffer?
    private var tokBuffer: AVAudioPCMBuffer?
    private var vylBuffer: AVAudioPCMBuffer?
    private var clickBuffer: AVAudioPCMBuffer?

    private init() {
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        let mainMixer = engine.mainMixerNode
        engine.attach(playerNode)
        
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1)!
        engine.connect(playerNode, to: mainMixer, format: format)

        nokBuffer = generateClickBuffer(format: format, frequency: 1200, decay: 0.005, subFreq: 180)
        tokBuffer = generateClickBuffer(format: format, frequency: 650, decay: 0.012, subFreq: 120)
        vylBuffer = generateClickBuffer(format: format, frequency: 2400, decay: 0.003, subFreq: 0)
        clickBuffer = generateClickBuffer(format: format, frequency: 1800, decay: 0.008, subFreq: 300)

        do {
            try engine.start()
            isSetup = true
        } catch {
        }
    }

    private func generateClickBuffer(format: AVAudioFormat, frequency: Float, decay: Float, subFreq: Float) -> AVAudioPCMBuffer? {
        let sampleRate = Float(format.sampleRate)
        let durationSamples = Int(sampleRate * decay * 3.0)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(durationSamples)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(durationSamples)

        let channelData = buffer.floatChannelData![0]

        for i in 0..<durationSamples {
            let t = Float(i) / sampleRate
            let env = exp(-t / decay)
            let mainTone = sin(2.0 * .pi * frequency * t)
            let subTone = subFreq > 0 ? sin(2.0 * .pi * subFreq * t) * 0.5 : 0.0
            let noise = Float.random(in: -0.2...0.2) * exp(-t / (decay * 0.5))
            
            channelData[i] = (mainTone * 0.6 + subTone + noise) * env * 0.4
        }

        return buffer
    }

    func playScrollTick(style: Int, volume: Float) {
        guard SettingsManager.shared.isSoundEnabled, volume > 0 else { return }

        let buffer: AVAudioPCMBuffer?
        switch style {
        case 1: buffer = tokBuffer
        case 2: buffer = vylBuffer
        case 3: buffer = clickBuffer
        default: buffer = nokBuffer
        }

        guard let soundBuffer = buffer else { return }
        playSoundBuffer(soundBuffer, volume: volume)
    }

    func playClickSound(volume: Float) {
        guard SettingsManager.shared.isSoundEnabled, volume > 0 else { return }
        if let buffer = clickBuffer {
            playSoundBuffer(buffer, volume: volume)
        }
    }

    private func playSoundBuffer(_ buffer: AVAudioPCMBuffer, volume: Float) {
        if !engine.isRunning {
            try? engine.start()
        }
        playerNode.volume = volume
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }
}
