import AppKit
import AVFoundation
import SpriteKit

/// Original artwork and generated tones. No sampled Atari assets are included.
enum ArcadeEffects {
    static func shield() -> SKNode {
        let shield = SKNode()
        shield.zPosition = 10
        let outer = SKShapeNode(circleOfRadius: 32)
        outer.name = "shieldOutline"
        outer.lineWidth = 2.5
        outer.fillColor = .clear
        outer.strokeColor = .white
        shield.addChild(outer)

        let inner = SKShapeNode(circleOfRadius: 27)
        inner.name = "shieldInner"
        inner.lineWidth = 1.4
        inner.strokeColor = .white.withAlphaComponent(0.75)
        inner.fillColor = .clear
        shield.addChild(inner)

        shield.run(.repeatForever(.sequence([
            .scale(to: 1.07, duration: 0.26),
            .scale(to: 0.96, duration: 0.26)
        ])))
        shield.isHidden = true
        return shield
    }

    static func updateShield(_ shield: SKNode, modern: Bool, remaining: CGFloat, total: CGFloat) {
        let color: SKColor = modern ? ModernVisuals.ice : .white
        for case let ring as SKShapeNode in shield.children {
            ring.strokeColor = color.withAlphaComponent(ring.name == "shieldInner" ? 0.55 : 1)
            ring.glowWidth = modern ? 12 : 0
        }
        shield.alpha = remaining <= 1 ? 0.45 + 0.55 * CGFloat.random(in: 0...1) : 1
        shield.isHidden = remaining <= 0
    }

    static func classicComet() -> SKNode {
        let node = SKNode()
        node.zPosition = 9
        let body = SKShapeNode(circleOfRadius: 12)
        body.fillColor = .black
        body.strokeColor = .white
        body.lineWidth = 2.2
        node.addChild(body)
        for offset in [-1, 0, 1] {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -12, y: offset * 5))
            p.addLine(to: CGPoint(x: -165, y: offset * 13))
            let line = SKShapeNode(path: p)
            line.strokeColor = .white.withAlphaComponent(offset == 0 ? 0.95 : 0.56)
            line.lineWidth = offset == 0 ? 2 : 1
            node.addChild(line)
        }
        return node
    }

    static func saucer(modern: Bool) -> SKShapeNode {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -24, y: 0))
        p.addLine(to: CGPoint(x: -11, y: 10))
        p.addLine(to: CGPoint(x: 11, y: 10))
        p.addLine(to: CGPoint(x: 24, y: 0))
        p.addLine(to: CGPoint(x: 12, y: -7))
        p.addLine(to: CGPoint(x: -12, y: -7))
        p.closeSubpath()
        p.move(to: CGPoint(x: -11, y: 10))
        p.addLine(to: CGPoint(x: -5, y: 18))
        p.addLine(to: CGPoint(x: 6, y: 18))
        p.addLine(to: CGPoint(x: 11, y: 10))
        let ship = SKShapeNode(path: p)
        ship.strokeColor = modern ? .systemPink : .white
        ship.fillColor = .clear
        ship.lineWidth = 2
        ship.glowWidth = modern ? 8 : 0
        ship.zPosition = 5
        return ship
    }

    static func damageCrack(radius: CGFloat) -> SKShapeNode {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -radius * 0.60, y: radius * 0.30))
        p.addLine(to: CGPoint(x: -radius * 0.18, y: radius * 0.06))
        p.addLine(to: CGPoint(x: radius * 0.02, y: radius * 0.28))
        p.addLine(to: CGPoint(x: radius * 0.32, y: -radius * 0.10))
        p.addLine(to: CGPoint(x: radius * 0.66, y: -radius * 0.32))
        p.move(to: CGPoint(x: radius * 0.02, y: radius * 0.28))
        p.addLine(to: CGPoint(x: radius * 0.24, y: radius * 0.52))
        p.move(to: CGPoint(x: radius * 0.32, y: -radius * 0.10))
        p.addLine(to: CGPoint(x: radius * 0.06, y: -radius * 0.58))
        let crack = SKShapeNode(path: p)
        crack.strokeColor = .yellow
        crack.lineWidth = 3
        crack.zPosition = 3
        crack.isHidden = true
        return crack
    }
}

/// Lightweight procedurally generated arcade tones, played only when enabled.
/// The engine owns the player node and keeps a bounded number of queued samples.
final class ArcadeAudio {
    enum Effect { case fire, rock, shield, bounce, comet, nuclear, ship, saucer, wave }
    static let shared = ArcadeAudio()
    var enabled = true {
        didSet { if !enabled { stopThrust() } }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let thrustPlayer = AVAudioPlayerNode()
    private var thrustPlaying = false
    private lazy var thrustBuffer: AVAudioPCMBuffer? = makeThrustBuffer()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var started = false

    private init() {
        engine.attach(player)
        engine.attach(thrustPlayer)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.connect(thrustPlayer, to: engine.mainMixerNode, format: format)
        thrustPlayer.volume = 0.45
        engine.mainMixerNode.outputVolume = 0.30
    }

    private func ensureEngine() -> Bool {
        if started { return true }
        do {
            try engine.start()
            player.play()
            started = true
            return true
        } catch {
            return false // Audio is optional; gameplay must continue without it.
        }
    }

    /// Continuous, looped rocket rumble, rather than 60 one-shot sounds per second.
    /// Called from the game loop; does nothing when the state has not changed.
    func setThrust(_ active: Bool) {
        guard active && enabled else {
            stopThrust()
            return
        }
        guard !thrustPlaying else { return }
        guard ensureEngine(), let buffer = thrustBuffer else { return }
        thrustPlayer.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
        thrustPlayer.play()
        thrustPlaying = true
    }

    func stopThrust() {
        guard thrustPlaying else { return }
        thrustPlayer.stop()
        thrustPlaying = false
    }

    /// A deliberately synthetic layered rocket tone: low oscillator, rumble,
    /// and filtered-sounding noise. Reusing one buffer keeps CPU cost low.
    private func makeThrustBuffer() -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(format.sampleRate * 0.45)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?.pointee else { return nil }
        buffer.frameLength = frames
        let count = Int(frames)
        for i in 0..<count {
            let t = Double(i) / format.sampleRate
            // 55 Hz fundamental plus a weak harmonic and modulated turbulence.
            let low = sin(2 * .pi * 55 * t) * 0.39
            let harmonic = sin(2 * .pi * 110 * t) * 0.15
            let pulsation = 0.68 + 0.16 * sin(2 * .pi * (1 / 0.45) * t)
            let grit = Double.random(in: -1...1) * 0.23
            // Smooth seam when the node loops the buffer.
            let seam = min(1, Double(min(i, count - i - 1)) / 800)
            samples[i] = Float((low + harmonic + grit) * pulsation * seam * 0.44)
        }
        return buffer
    }

    func play(_ effect: Effect) {
        guard enabled && ensureEngine() else { return }

        let duration: Double
        let f0: Double
        let f1: Double
        let noise: Float
        switch effect {
        case .fire: duration = 0.07; f0 = 780; f1 = 230; noise = 0.08
        case .rock: duration = 0.19; f0 = 160; f1 = 52; noise = 0.44
        case .shield: duration = 0.22; f0 = 350; f1 = 870; noise = 0.02
        case .bounce: duration = 0.16; f0 = 260; f1 = 710; noise = 0.05
        case .comet: duration = 0.58; f0 = 240; f1 = 38; noise = 0.25
        case .nuclear: duration = 0.92; f0 = 105; f1 = 17; noise = 0.70
        case .ship: duration = 0.48; f0 = 280; f1 = 46; noise = 0.40
        case .saucer: duration = 0.15; f0 = 340; f1 = 650; noise = 0.04
        case .wave: duration = 0.24; f0 = 330; f1 = 880; noise = 0.0
        }
        let frames = AVAudioFrameCount(duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?.pointee else { return }
        buffer.frameLength = frames
        var phase: Double = 0
        for n in 0..<Int(frames) {
            let progress = Double(n) / Double(frames)
            let frequency = f0 + (f1 - f0) * progress
            phase += (2 * .pi * frequency) / format.sampleRate
            let envelope = Float(pow(1 - progress, 2.4) * min(1, progress * 55))
            let tone = Float(sin(phase)) * (1 - noise)
            let grit = Float.random(in: -1...1) * noise
            samples[n] = (tone + grit) * envelope * 0.36
        }
        player.scheduleBuffer(buffer, completionHandler: nil)
    }
}
