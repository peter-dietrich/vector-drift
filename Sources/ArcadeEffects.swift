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

    /// Original predatory alien raider inspired by the swept-wing language of
    /// classic science-fiction spacecraft. Not a reproduction of any franchise ship.
    static func saucer(modern: Bool) -> SKShapeNode {
        let hull = CGMutablePath()
        hull.move(to: CGPoint(x: 29, y: 0))       // Forward beak
        hull.addLine(to: CGPoint(x: 9, y: 7))
        hull.addLine(to: CGPoint(x: -4, y: 13))
        hull.addLine(to: CGPoint(x: -27, y: 24))    // Upper swept wing
        hull.addLine(to: CGPoint(x: -15, y: 5))
        hull.addLine(to: CGPoint(x: -18, y: 0))
        hull.addLine(to: CGPoint(x: -15, y: -5))
        hull.addLine(to: CGPoint(x: -27, y: -24))   // Lower swept wing
        hull.addLine(to: CGPoint(x: -4, y: -13))
        hull.addLine(to: CGPoint(x: 9, y: -7))
        hull.closeSubpath()

        let ship = SKShapeNode(path: hull)
        ship.name = "alienRaider"
        ship.strokeColor = modern ? .systemRed : .white
        ship.fillColor = modern
            ? SKColor(calibratedRed: 0.26, green: 0.04, blue: 0.10, alpha: 0.86)
            : .black
        ship.lineWidth = modern ? 2.7 : 1.7
        ship.glowWidth = modern ? 9 : 0
        ship.zPosition = 6

        let panel = CGMutablePath()
        panel.move(to: CGPoint(x: -20, y: 18))
        panel.addLine(to: CGPoint(x: -6, y: 4))
        panel.addLine(to: CGPoint(x: 17, y: 0))
        panel.addLine(to: CGPoint(x: -6, y: -4))
        panel.addLine(to: CGPoint(x: -20, y: -18))
        let inlay = SKShapeNode(path: panel)
        inlay.name = "raiderInlay"
        inlay.strokeColor = modern ? .systemOrange : .white.withAlphaComponent(0.60)
        inlay.lineWidth = 1.1
        ship.addChild(inlay)

        let bridge = SKShapeNode(ellipseOf: CGSize(width: 15, height: 8))
        bridge.name = "raiderBridge"
        bridge.position = CGPoint(x: 1, y: 0)
        bridge.fillColor = modern ? .systemRed : .black
        bridge.strokeColor = modern ? .systemPink : .white
        bridge.lineWidth = 1
        bridge.glowWidth = modern ? 4 : 0
        ship.addChild(bridge)

        for y in [-15, 15] as [CGFloat] {
            let engine = SKShapeNode(circleOfRadius: 3)
            engine.name = "raiderEngine"
            engine.position = CGPoint(x: -23, y: y)
            engine.fillColor = modern ? .systemOrange : .white
            engine.strokeColor = .clear
            engine.glowWidth = modern ? 7 : 0
            ship.addChild(engine)
        }
        return ship
    }

    static func styleRaider(_ ship: SKShapeNode, modern: Bool) {
        ship.strokeColor = modern ? .systemRed : .white
        ship.fillColor = modern
            ? SKColor(calibratedRed: 0.26, green: 0.04, blue: 0.10, alpha: 0.86)
            : .black
        ship.glowWidth = modern ? 9 : 0
        ship.lineWidth = modern ? 2.7 : 1.7
        for case let part as SKShapeNode in ship.children {
            switch part.name {
            case "raiderInlay":
                part.strokeColor = modern ? .systemOrange : .white.withAlphaComponent(0.6)
            case "raiderBridge":
                part.fillColor = modern ? .systemRed : .black
                part.strokeColor = modern ? .systemPink : .white
                part.glowWidth = modern ? 4 : 0
            case "raiderEngine":
                part.fillColor = modern ? .systemOrange : .white
                part.glowWidth = modern ? 7 : 0
            default: break
            }
        }
    }

    /// Flat-paneled communications satellite, with twin solar wings and an
    /// articulated central bus; entirely procedural, not a branded asset.
    static func satellite(modern: Bool) -> SKNode {
        let root = SKNode()
        root.name = "driftingSatellite"
        root.zPosition = 4
        let white = modern ? SKColor(calibratedWhite: 0.85, alpha: 1) : SKColor.white
        let blue = modern
            ? SKColor(calibratedRed: 0.12, green: 0.38, blue: 0.62, alpha: 0.94)
            : SKColor.black
        let rail = SKShapeNode(rectOf: CGSize(width: 100, height: 2))
        rail.fillColor = white
        rail.strokeColor = .clear
        root.addChild(rail)
        for side in [-1, 1] as [CGFloat] {
            let wing = SKShapeNode(rectOf: CGSize(width: 36, height: 16), cornerRadius: 1.5)
            wing.position = CGPoint(x: side * 35, y: 0)
            wing.fillColor = blue
            wing.strokeColor = white
            wing.lineWidth = 1.5
            root.addChild(wing)
            for delta in [-9, 0, 9] as [CGFloat] {
                let cell = SKShapeNode(rectOf: CGSize(width: 1, height: 14))
                cell.position = CGPoint(x: side * 35 + delta, y: 0)
                cell.fillColor = white.withAlphaComponent(0.58)
                cell.strokeColor = .clear
                root.addChild(cell)
            }
        }
        let bus = SKShapeNode(rectOf: CGSize(width: 18, height: 12), cornerRadius: 2)
        bus.fillColor = modern ? .darkGray : .black
        bus.strokeColor = white
        bus.lineWidth = 2
        root.addChild(bus)
        let antenna = SKShapeNode(circleOfRadius: 5)
        antenna.position = CGPoint(x: 0, y: 12)
        antenna.strokeColor = white
        antenna.fillColor = .clear
        antenna.lineWidth = 1.3
        root.addChild(antenna)
        let blink = SKShapeNode(circleOfRadius: 2)
        blink.position = CGPoint(x: 0, y: -4)
        blink.fillColor = modern ? .systemCyan : .white
        blink.strokeColor = .clear
        blink.glowWidth = modern ? 5 : 0
        blink.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.12, duration: 0.65),
            .fadeAlpha(to: 1, duration: 0.20),
            .wait(forDuration: 1.5)
        ])))
        root.addChild(blink)
        return root
    }

    /// ISS-inspired procedural silhouette with four detachable photovoltaic
    /// wings, transverse truss, radiators, and pressurized modules. No NASA image
    /// assets are embedded: geometry is composed from SpriteKit primitives.
    static func station(modern: Bool, damage: Int = 0) -> SKNode {
        let root = SKNode()
        root.name = "orbitalStation"
        root.zPosition = 4
        let metal = SKColor(calibratedRed: 0.73, green: 0.82, blue: 0.87, alpha: 1)
        let shadow = SKColor(calibratedRed: 0.19, green: 0.29, blue: 0.39, alpha: 1)
        let solar = modern
            ? SKColor(calibratedRed: 0.21, green: 0.33, blue: 0.57, alpha: 1)
            : SKColor(calibratedWhite: 0.42, alpha: 1)
        let copper = SKColor(calibratedRed: 0.76, green: 0.47, blue: 0.23, alpha: 1)

        func beam(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                  parent: SKNode = root) {
            let shape = SKShapeNode(rectOf: CGSize(width: w, height: h))
            shape.position = CGPoint(x: x, y: y)
            shape.strokeColor = metal
            shape.fillColor = shadow
            shape.lineWidth = 1
            parent.addChild(shape)
        }
        // The recognizable 250-point main ISS truss, with repeating bracing.
        beam(0, 0, 245, 6)
        beam(0, 8, 235, 2)
        beam(0, -8, 235, 2)
        for x in stride(from: -112, through: 112, by: 16) {
            beam(CGFloat(x), 0, 1.6, 15)
        }
        // Four distinct, detachable solar-array assemblies spanning both sides.
        // Numbered in the order they detach; damage is persisted in saves.
        for index in 0..<4 {
            if damage >= index + 1 { continue }
            let side: CGFloat = index < 2 ? -1 : 1
            let slot: CGFloat = index.isMultiple(of: 2) ? 0 : 1
            let panel = SKNode()
            panel.name = "stationArray\(index)"
            panel.position = CGPoint(x: side * (79 + slot * 40), y: 0)
            root.addChild(panel)
            beam(0, 0, 3, 88, parent: panel)
            for half in [-1, 1] as [CGFloat] {
                let wing = SKShapeNode(rectOf: CGSize(width: 28, height: 38))
                wing.position = CGPoint(x: 0, y: half * 24)
                wing.strokeColor = metal
                wing.fillColor = solar
                wing.lineWidth = 1.1
                panel.addChild(wing)
                for y in [-12, -4, 4, 12] as [CGFloat] {
                    beam(0, half * 24 + y, 27, 0.65, parent: panel)
                }
                for x in [-9, 0, 9] as [CGFloat] {
                    beam(x, half * 24, 0.6, 37, parent: panel)
                }
            }
            let pivot = SKShapeNode(circleOfRadius: 4)
            pivot.fillColor = copper
            pivot.strokeColor = metal
            pivot.lineWidth = 1.1
            panel.addChild(pivot)
        }

        // White thermal radiator rectangles near the main truss.
        for x in [-45, -25, 25, 45] as [CGFloat] {
            let radiator = SKShapeNode(rectOf: CGSize(width: 14, height: 26))
            radiator.position = CGPoint(x: x, y: 22)
            radiator.fillColor = metal.withAlphaComponent(0.88)
            radiator.strokeColor = .white
            radiator.lineWidth = 0.8
            root.addChild(radiator)
        }
        // Longitudinal pressurized module spine: Unity/Destiny/Zvezda silhouette.
        beam(0, -18, 13, 93)
        for (y, w, h) in [(-58.0, 22.0, 29.0), (-28.0, 26.0, 28.0),
                          (3.0, 20.0, 24.0), (37.0, 19.0, 34.0)] {
            let lab = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
            lab.position = CGPoint(x: 0, y: y)
            lab.strokeColor = metal
            lab.fillColor = shadow
            lab.lineWidth = 2
            root.addChild(lab)
        }
        // Cross-axis laboratory, exposed equipment, cupola and docking node.
        beam(22, -24, 40, 14)
        let dock = SKShapeNode(circleOfRadius: 8)
        dock.position = CGPoint(x: 44, y: -24)
        dock.fillColor = shadow
        dock.strokeColor = metal
        dock.lineWidth = 2
        root.addChild(dock)
        let cupola = SKShapeNode(circleOfRadius: 5)
        cupola.position = CGPoint(x: -13, y: -39)
        cupola.fillColor = modern ? .systemCyan : .white
        cupola.strokeColor = metal
        root.addChild(cupola)
        root.alpha = 0.96
        return root
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
    enum Effect {
        case fire, beam, rock, rockBurstSmall, rockBurstMedium, rockBurstLarge
        case shield, bounce, comet, nuclear, ship, saucer, wave
    }
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

    /// Breaking a rock is different from damaging its shell. Its size determines
    /// the depth of the cracking thud, while each burst gets subtle variation.
    func playRockBreak(level: Int) {
        let effect: Effect = level <= 2 ? .rockBurstSmall :
                             level == 3 ? .rockBurstMedium : .rockBurstLarge
        play(effect)
    }

    /// Dry, noise-based rock impacts rather than ringing oscillators.
    /// A broadband fracture, dense midrange rubble and a low band-limited
    /// thump are shaped independently. No sustained pitched sine wave.
    private func playRockBreakSample(_ effect: Effect) {
        let weight: Double
        switch effect {
        case .rock: weight = 0.35           // Nonfatal crack/chip
        case .rockBurstSmall: weight = 0.64
        case .rockBurstMedium: weight = 1.0
        case .rockBurstLarge: weight = 1.46
        default: return
        }

        let duration = 0.105 + weight * 0.24
        let frames = AVAudioFrameCount(duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: frames),
              let samples = buffer.floatChannelData?.pointee else { return }
        buffer.frameLength = frames

        let sampleRate = format.sampleRate
        let variation = Double.random(in: 0.88...1.12)
        // Overlapping one-pole filters form physical-sounding noise bands.
        // Using noise rather than a harmonic tone removes the tin-can ring.
        let lowAlpha = 1 - exp(-2 * .pi * (255 / weight) / sampleRate)
        let subAlpha = 1 - exp(-2 * .pi * (47 / weight) / sampleRate)
        let midAlpha = 1 - exp(-2 * .pi * (1550 / weight) / sampleRate)
        var lowPass = 0.0
        var subPass = 0.0
        var midPass = 0.0
        var previousWhite = 0.0

        for index in 0..<Int(frames) {
            let t = Double(index) / sampleRate
            let progress = t / duration
            let white = Double.random(in: -1...1)

            lowPass += lowAlpha * (white - lowPass)
            subPass += subAlpha * (white - subPass)
            midPass += midAlpha * (white - midPass)

            let lowBody = lowPass - subPass
            let grittyRubble = midPass - lowPass
            let drySnap = white - midPass

            let firstCrack = exp(-t * 135 * variation)
            // Rocks often shear in two stages before the remaining grit falls.
            let secondaryAt = 0.030 + 0.022 * weight
            let secondCrack = t >= secondaryAt
                ? exp(-(t - secondaryAt) * 96 * variation) : 0.0
            let bodyEnvelope = exp(-t * (9.8 / weight) * variation)
            let rubbleEnvelope = exp(-t * (7.3 / weight))
            let attack = min(1.0, t * 1800)
            let release = pow(max(0, 1 - progress), 1.2)

            // More size = more low-mid weight and a longer tumbling tail.
            // High frequencies are isolated to brief impacts, not ringing.
            let crack = drySnap * (firstCrack * 0.22 + secondCrack * 0.10)
            let thump = lowBody * (1.30 + weight * 0.43) * bodyEnvelope
            let crumble = grittyRubble * (0.32 + weight * 0.10) * rubbleEnvelope
            let fizz = (white - previousWhite) * firstCrack * 0.035
            let sample = (crack + thump + crumble + fizz) *
                         attack * release * 0.82
            samples[index] = Float(max(-1, min(1, sample)))
            previousWhite = white
        }
        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    func play(_ effect: Effect) {
        guard enabled && ensureEngine() else { return }
        switch effect {
        case .rock, .rockBurstSmall, .rockBurstMedium, .rockBurstLarge:
            playRockBreakSample(effect)
            return
        default: break
        }

        let duration: Double
        let f0: Double
        let f1: Double
        let noise: Float
        switch effect {
        case .fire: duration = 0.07; f0 = 780; f1 = 230; noise = 0.08
        case .beam: duration = 0.30; f0 = 1720; f1 = 390; noise = 0.10
        case .rock, .rockBurstSmall, .rockBurstMedium, .rockBurstLarge:
            return // All rock impacts use the noise-based fracture synthesizer.
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
