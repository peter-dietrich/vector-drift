import AppKit
import SpriteKit
import SwiftUI

@main
struct VectorDriftApp: App {
    var body: some Scene {
        WindowGroup {
            GameWindow()
                .frame(minWidth: 760, minHeight: 540)
        }
        .defaultSize(width: 1080, height: 760)
    }
}

private enum Look: String, CaseIterable, Identifiable {
    case classic, modern
    var id: String { rawValue }
    var title: String { self == .classic ? "Classic" : "Modern Vector" }
}

private struct GameWindow: View {
    @AppStorage("visualMode") private var mode = Look.classic.rawValue
    @State private var game: DriftScene = {
        let scene = DriftScene(size: CGSize(width: 1080, height: 670))
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("VECTOR DRIFT")
                    .font(.system(.headline, design: .monospaced))
                Spacer()
                Picker("Graphics", selection: $mode) {
                    ForEach(Look.allCases) { look in Text(look.title).tag(look.rawValue) }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                Button("New Game") { game.restart() }
                    .keyboardShortcut("r", modifiers: [.command])
            }
            .padding(.horizontal, 18)
            .frame(height: 54)
            .background(Color(white: 0.10))
            GameView(scene: game)
                .background(.black)
            HStack {
                Text("← → Rotate    ↑ Thrust    Space Fire    ↓ Hyperspace    P Pause    R Restart")
                Spacer()
                Text("Click playfield for keyboard focus")
            }
            .font(.system(size: 11, design: .monospaced))
            .padding(12)
            .background(Color(white: 0.10))
        }
        .foregroundStyle(.white)
        .onAppear { game.modern = mode == Look.modern.rawValue }
        .onChange(of: mode) { value in game.modern = value == Look.modern.rawValue }
    }
}

private struct GameView: NSViewRepresentable {
    let scene: DriftScene
    func makeNSView(context: Context) -> KeyboardView {
        let view = KeyboardView()
        view.preferredFramesPerSecond = 60
        view.presentScene(scene)
        return view
    }
    func updateNSView(_ view: KeyboardView, context: Context) {
        if view.scene !== scene { view.presentScene(scene) }
    }
}

private final class KeyboardView: SKView {
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }
    override func keyDown(with event: NSEvent) {
        (scene as? DriftScene)?.key(event.keyCode, down: true, isRepeat: event.isARepeat)
    }
    override func keyUp(with event: NSEvent) {
        (scene as? DriftScene)?.key(event.keyCode, down: false, isRepeat: false)
    }
    override func resignFirstResponder() -> Bool {
        (scene as? DriftScene)?.clearKeys()
        return super.resignFirstResponder()
    }
}

private struct Boulder {
    var node: SKShapeNode
    var velocity: CGVector
    var radius: CGFloat
    var level: Int
    var spin: CGFloat
}
private struct Laser {
    var node: SKShapeNode
    var velocity: CGVector
    var remaining: CGFloat
}

final class DriftScene: SKScene {
    var modern = false { didSet { updateStyle() } }
    private var boulders: [Boulder] = []
    private var lasers: [Laser] = []
    private var held = Set<UInt16>()
    private var lastTime: TimeInterval = 0
    private var elapsed: CGFloat = 0
    private var lastFire: CGFloat = -2
    private var lastWarp: CGFloat = -10
    private var protectedUntil: CGFloat = 0
    private var heading: CGFloat = 0
    private var velocity = CGVector.zero
    private var score = 0
    private var high = UserDefaults.standard.integer(forKey: "highScore")
    private var lives = 3
    private var wave = 1
    private var stopped = false
    private var over = false
    private var ready = false
    private let ship: SKShapeNode = {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: 19))
        p.addLine(to: CGPoint(x: -12, y: -12))
        p.addLine(to: CGPoint(x: 0, y: -7))
        p.addLine(to: CGPoint(x: 12, y: -12))
        p.closeSubpath()
        return SKShapeNode(path: p)
    }()
    private let hud = SKLabelNode(fontNamed: "Menlo-Bold")
    private let message = SKLabelNode(fontNamed: "Menlo-Bold")

    override func didMove(to view: SKView) {
        guard !ready else { return }
        ready = true
        backgroundColor = .black
        ship.fillColor = .clear
        ship.lineWidth = 2
        ship.zPosition = 5
        addChild(ship)
        hud.fontSize = 15
        hud.horizontalAlignmentMode = .left
        hud.verticalAlignmentMode = .top
        addChild(hud)
        message.fontSize = 28
        message.horizontalAlignmentMode = .center
        addChild(message)
        restart()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        hud.position = CGPoint(x: 18, y: size.height - 18)
        message.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    func restart() {
        guard ready else { return }
        boulders.forEach { $0.node.removeFromParent() }
        lasers.forEach { $0.node.removeFromParent() }
        boulders.removeAll()
        lasers.removeAll()
        held.removeAll()
        score = 0; lives = 3; wave = 1
        elapsed = 0; lastTime = 0; lastFire = -2; lastWarp = -10
        stopped = false; over = false
        resetShip()
        protectedUntil = 2
        ship.isHidden = false
        message.text = ""
        spawnWave()
        updateHud()
        updateStyle()
    }

    private func resetShip() {
        ship.position = CGPoint(x: size.width / 2, y: size.height / 2)
        ship.zRotation = 0
        heading = 0
        velocity = .zero
    }

    func clearKeys() { held.removeAll() }

    func key(_ code: UInt16, down: Bool, isRepeat: Bool) {
        if down { held.insert(code) } else { held.remove(code) }
        guard down && !isRepeat else { return }
        switch code {
        case 35: // P
            if !over {
                stopped.toggle()
                message.text = stopped ? "PAUSED" : ""
            }
        case 15: restart() // R
        case 125: if !stopped && !over { hyperspace() }
        default: break
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? CGFloat(1.0 / 60) : CGFloat(min(max(currentTime - lastTime, 0), 1.0 / 30))
        lastTime = currentTime
        guard ready && !over && !stopped else { return }
        elapsed += dt

        if held.contains(123) { heading += 3.7 * dt }
        if held.contains(124) { heading -= 3.7 * dt }
        let forward = CGVector(dx: -sin(heading), dy: cos(heading))
        if held.contains(126) {
            velocity.dx += forward.dx * 265 * dt
            velocity.dy += forward.dy * 265 * dt
            let speed = hypot(velocity.dx, velocity.dy)
            if speed > 440 { velocity.dx *= 440 / speed; velocity.dy *= 440 / speed }
        }
        ship.zRotation = heading
        ship.position = wrapped(CGPoint(x: ship.position.x + velocity.dx * dt,
                                        y: ship.position.y + velocity.dy * dt), margin: 15)
        ship.alpha = elapsed < protectedUntil && Int(elapsed * 10).isMultiple(of: 2) ? 0.25 : 1

        if held.contains(49) && elapsed - lastFire > 0.16 && lasers.count < 6 {
            lastFire = elapsed
            let bullet = SKShapeNode(circleOfRadius: 2)
            bullet.position = CGPoint(x: ship.position.x + forward.dx * 20,
                                      y: ship.position.y + forward.dy * 20)
            bullet.fillColor = .white
            addChild(bullet)
            lasers.append(Laser(node: bullet,
                                velocity: CGVector(dx: velocity.dx + forward.dx * 540,
                                                   dy: velocity.dy + forward.dy * 540),
                                remaining: 0.9))
        }

        for i in boulders.indices {
            boulders[i].node.position = wrapped(CGPoint(
                x: boulders[i].node.position.x + boulders[i].velocity.dx * dt,
                y: boulders[i].node.position.y + boulders[i].velocity.dy * dt),
                margin: boulders[i].radius)
            boulders[i].node.zRotation += boulders[i].spin * dt
        }
        for i in lasers.indices {
            lasers[i].remaining -= dt
            lasers[i].node.position = wrapped(CGPoint(
                x: lasers[i].node.position.x + lasers[i].velocity.dx * dt,
                y: lasers[i].node.position.y + lasers[i].velocity.dy * dt), margin: 0)
        }

        for i in lasers.indices.reversed() {
            if lasers[i].remaining <= 0 {
                lasers.remove(at: i).node.removeFromParent()
                continue
            }
            if let j = boulders.firstIndex(where: {
                hypot($0.node.position.x - lasers[i].node.position.x,
                      $0.node.position.y - lasers[i].node.position.y) < $0.radius + 2
            }) {
                lasers.remove(at: i).node.removeFromParent()
                let rock = boulders.remove(at: j)
                rock.node.removeFromParent()
                score += rock.level == 3 ? 20 : rock.level == 2 ? 50 : 100
                if score > high {
                    high = score
                    UserDefaults.standard.set(high, forKey: "highScore")
                }
                if rock.level > 1 {
                    for direction in [-0.75, 0.75] as [CGFloat] {
                        let angle = atan2(rock.velocity.dy, rock.velocity.dx) + direction
                        let speed: CGFloat = rock.level == 3 ? 115 : 155
                        spawnRock(level: rock.level - 1, at: rock.node.position,
                                  velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed))
                    }
                }
                updateHud()
            }
        }

        if elapsed >= protectedUntil &&
            boulders.contains(where: {
                hypot($0.node.position.x - ship.position.x,
                      $0.node.position.y - ship.position.y) < $0.radius + 11
            }) {
            lives -= 1
            updateHud()
            if lives <= 0 {
                over = true
                ship.isHidden = true
                message.text = "GAME OVER · PRESS R"
            } else {
                resetShip()
                protectedUntil = elapsed + 2
            }
        }
        if boulders.isEmpty {
            wave += 1
            spawnWave()
            protectedUntil = elapsed + 1.5
            updateHud()
        }
    }

    private func hyperspace() {
        guard elapsed - lastWarp > 4.5 else { return }
        lastWarp = elapsed
        ship.position = CGPoint(x: .random(in: 40...max(41, size.width - 40)),
                                y: .random(in: 40...max(41, size.height - 40)))
        velocity = .zero
        protectedUntil = elapsed + 1.4
    }

    private func spawnWave() {
        for _ in 0..<min(3 + wave, 10) {
            var point = CGPoint.zero
            for _ in 0..<30 {
                point = CGPoint(x: .random(in: 40...max(41, size.width - 40)),
                                y: .random(in: 40...max(41, size.height - 40)))
                if hypot(point.x - ship.position.x, point.y - ship.position.y) > 170 { break }
            }
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 35...78) + CGFloat(wave) * 4
            spawnRock(level: 3, at: point,
                      velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed))
        }
    }

    private func spawnRock(level: Int, at point: CGPoint, velocity: CGVector) {
        let radius: CGFloat = level == 3 ? 43 : level == 2 ? 27 : 15
        let path = CGMutablePath()
        let vertices = 12
        for i in 0..<vertices {
            let angle = 2 * CGFloat.pi * CGFloat(i) / CGFloat(vertices)
            let radiusVariation = CGFloat.random(in: 0.7...1.14)
            let vertex = CGPoint(x: cos(angle) * radius * radiusVariation,
                                 y: sin(angle) * radius * radiusVariation)
            if i == 0 { path.move(to: vertex) } else { path.addLine(to: vertex) }
        }
        path.closeSubpath()
        let node = SKShapeNode(path: path)
        node.position = point
        node.fillColor = .clear
        node.lineWidth = 1.7
        addChild(node)
        boulders.append(Boulder(node: node, velocity: velocity, radius: radius,
                                level: level, spin: .random(in: -1.2...1.2)))
        node.strokeColor = modern ? .cyan : .white
        node.glowWidth = modern ? 3 : 0
    }

    private func updateHud() {
        hud.text = String(format: "SCORE %06d     HIGH %06d     WAVE %d     LIVES %d",
                          score, high, wave, lives)
    }

    private func updateStyle() {
        guard ready else { return }
        backgroundColor = modern
            ? SKColor(calibratedRed: 0.015, green: 0.025, blue: 0.085, alpha: 1)
            : .black
        let color: SKColor = modern ? .cyan : .white
        ship.strokeColor = color
        ship.glowWidth = modern ? 5 : 0
        hud.fontColor = color
        message.fontColor = color
        for rock in boulders {
            rock.node.strokeColor = color
            rock.node.glowWidth = modern ? 3 : 0
        }
        for laser in lasers {
            laser.node.fillColor = modern ? .yellow : .white
            laser.node.strokeColor = laser.node.fillColor
        }
    }

    private func wrapped(_ p: CGPoint, margin: CGFloat) -> CGPoint {
        var result = p
        if result.x < -margin { result.x = size.width + margin }
        if result.x > size.width + margin { result.x = -margin }
        if result.y < -margin { result.y = size.height + margin }
        if result.y > size.height + margin { result.y = -margin }
        return result
    }
}
