import AVFoundation
import Foundation

final class ProceduralAudioEngine {
    static let shared = ProceduralAudioEngine()

    private let engine = AVAudioEngine()
    private let ambientPlayer = AVAudioPlayerNode()
    private let sfxPlayer = AVAudioPlayerNode()
    private let sampleRate: Double = 44100.0
    private var isRunning = false

    private var ambientBuffer: AVAudioPCMBuffer?
    private var footstepBuffer: AVAudioPCMBuffer?
    private var jumpBuffer: AVAudioPCMBuffer?
    private var clickBuffer: AVAudioPCMBuffer?
    private var alertBuffer: AVAudioPCMBuffer?

    private init() {
        setupAudioSession()
        buildBuffers()
        setupEngine()
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func setupEngine() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        engine.attach(ambientPlayer)
        engine.attach(sfxPlayer)

        engine.connect(ambientPlayer, to: engine.mainMixerNode, format: format)
        engine.connect(sfxPlayer, to: engine.mainMixerNode, format: format)

        ambientPlayer.volume = 0.34
        sfxPlayer.volume = 0.55
    }

    func start() {
        if !isRunning {
            do {
                try engine.start()
                isRunning = true
            } catch {
                return
            }
        }
        if let ambient = ambientBuffer, !ambientPlayer.isPlaying {
            ambientPlayer.scheduleBuffer(ambient, at: nil, options: .loops, completionHandler: nil)
            ambientPlayer.play()
        }
    }

    func playFootstep() {
        guard isRunning, let buf = footstepBuffer else { return }
        sfxPlayer.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        if !sfxPlayer.isPlaying { sfxPlayer.play() }
    }

    func playJump() {
        guard isRunning, let buf = jumpBuffer else { return }
        sfxPlayer.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        if !sfxPlayer.isPlaying { sfxPlayer.play() }
    }

    func playFlashlightClick() {
        guard isRunning, let buf = clickBuffer else { return }
        sfxPlayer.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        if !sfxPlayer.isPlaying { sfxPlayer.play() }
    }

    func playAlert() {
        guard isRunning, let buf = alertBuffer else { return }
        sfxPlayer.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        if !sfxPlayer.isPlaying { sfxPlayer.play() }
    }

    private func buildBuffers() {
        ambientBuffer = generateAmbientWindAndHeartbeat(duration: 4.0)
        footstepBuffer = generateFootstep(duration: 0.11)
        jumpBuffer = generateJump(duration: 0.22)
        clickBuffer = generateClick(duration: 0.05)
        alertBuffer = generateAlertDrone(duration: 0.45)
    }

    private func generateAmbientWindAndHeartbeat(duration: Double) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData else { return nil }
        let data = channelData[0]

        var lastNoise: Float = 0.0
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let white = Float.random(in: -1...1)
            lastNoise = lastNoise * 0.985 + white * 0.015
            let windMod = Float(0.65 + 0.35 * sin(2.0 * .pi * 0.25 * t))
            let subDrone = Float(sin(2.0 * .pi * 48.0 * t)) * 0.08

            let cycle = t.truncatingRemainder(dividingBy: 2.0)
            var beat: Float = 0.0
            if cycle < 0.14 {
                let env = Float(sin(.pi * (cycle / 0.14)))
                beat = env * Float(sin(2.0 * .pi * 55.0 * cycle)) * 0.42
            } else if cycle >= 0.24 && cycle < 0.40 {
                let local = cycle - 0.24
                let env = Float(sin(.pi * (local / 0.16)))
                beat = env * Float(sin(2.0 * .pi * 46.0 * local)) * 0.30
            }

            data[i] = max(-0.95, min(0.95, lastNoise * 4.5 * windMod + subDrone + beat))
        }
        return buffer
    }

    private func generateFootstep(duration: Double) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData else { return nil }
        let data = channelData[0]

        var filtered: Float = 0.0
        for i in 0..<Int(frameCount) {
            let progress = Float(i) / Float(frameCount)
            let env = pow(1.0 - progress, 2.5)
            let noise = Float.random(in: -1...1)
            filtered = filtered * 0.82 + noise * 0.18
            let thud = sin(Float(i) * 0.03) * 0.35
            data[i] = (filtered * 1.4 + thud) * env * 0.45
        }
        return buffer
    }

    private func generateJump(duration: Double) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData else { return nil }
        let data = channelData[0]

        var phase: Double = 0.0
        for i in 0..<Int(frameCount) {
            let progress = Double(i) / Double(frameCount)
            let freq = 95.0 + progress * 145.0
            phase += (2.0 * .pi * freq) / sampleRate
            let env = Float(sin(.pi * progress)) * Float(1.0 - progress * 0.4)
            let breath = Float.random(in: -0.15...0.15) * (1.0 - Float(progress))
            data[i] = (Float(sin(phase)) * 0.32 + breath) * env
        }
        return buffer
    }

    private func generateClick(duration: Double) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData else { return nil }
        let data = channelData[0]

        for i in 0..<Int(frameCount) {
            let p = Float(i) / Float(frameCount)
            let env = pow(1.0 - p, 4.0)
            let snap = sin(Float(i) * 0.45) * 0.5 + Float.random(in: -0.4...0.4)
            data[i] = snap * env * 0.6
        }
        return buffer
    }

    private func generateAlertDrone(duration: Double) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData else { return nil }
        let data = channelData[0]

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let env = Float(sin(.pi * (t / duration)))
            let s1 = Float(sin(2.0 * .pi * 110.0 * t))
            let s2 = Float(sin(2.0 * .pi * 116.5 * t))
            data[i] = (s1 + s2) * 0.25 * env
        }
        return buffer
    }
}
