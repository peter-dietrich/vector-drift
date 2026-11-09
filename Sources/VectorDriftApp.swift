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

fileprivate enum Difficulty: String, CaseIterable, Identifiable {
    case easy, medium, hard
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var speedMultiplier: CGFloat {
        switch self {
        case .easy: return 0.75
        case .medium: return 1
        case .hard: return 1.32
        }
    }

    var startingLives: Int {
        switch self {
        case .easy: return 5
        case .medium: return 3
        case .hard: return 2
        }
    }

    var bulletLifetime: CGFloat {
        switch self {
        case .easy: return 1.5
        case .medium: return 0.95
        case .hard: return 0.55
        }
    }

    var shootCooldown: CGFloat {
        switch self {
        case .easy: return 0.13
        case .medium: return 0.16
        case .hard: return 0.20
        }
    }

    var respawnProtection: CGFloat {
        switch self {
        case .easy: return 3.0
        case .medium: return 2.0
        case .hard: return 1.25
        }
    }

    var hyperspaceCooldown: CGFloat {
        switch self {
        case .easy: return 3
        case .medium: return 4.5
        case .hard: return 7
        }
    }

    var shieldDuration: CGFloat {
        switch self {
        case .easy: return 7
        case .medium: return 5
        case .hard: return 3
        }
    }

    var cometDelay: ClosedRange<CGFloat> {
        switch self {
        case .easy: return 15...23
        case .medium: return 11...18
        case .hard: return 5...9
        }
    }

    var saucerDelay: ClosedRange<CGFloat> {
        switch self {
        case .easy: return 27...35
        case .medium: return 19...27
        case .hard: return 12...19
        }
    }

    /// Asteroid size tiers include small fragments at level 1.
    var maximumRockLevel: Int {
        switch self {
        case .easy: return 3
        case .medium: return 4
        case .hard: return 5
        }
    }

    /// Easy's current starting density stays unchanged; Hard starts
    /// denser and adds two rocks per successive wave until capped.
    func rockCount(forWave wave: Int) -> Int {
        let additional = max(wave - 1, 0)
        switch self {
        case .easy: return min(3 + additional, 12)
        case .medium: return min(4 + additional, 13)
        case .hard: return min(7 + additional * 2, 19)
        }
    }

    /// Populate a wave with a mix of large rocks; a hit splits to the next
    /// smaller tier all the way down to size 1.
    func startingRockLevel(at index: Int) -> Int {
        switch self {
        case .easy:
            return 3
        case .medium:
            return index.isMultiple(of: 3) ? 4 : 3
        case .hard:
            if index.isMultiple(of: 4) { return 5 }
            return index.isMultiple(of: 3) ? 4 : 3
        }
    }

    func hitsToSplit(level: Int) -> Int {
        guard self == .hard else { return 1 }
        switch level {
        case 5: return 3
        case 4: return 2
        default: return 1
        }
    }
}

private struct GameWindow: View {
    @AppStorage("visualMode") private var mode = Look.classic.rawValue
    @AppStorage("difficulty") private var difficulty = Difficulty.medium.rawValue
    @AppStorage("soundEnabled") private var soundEnabled = true
    @State private var showScores = false
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
                HStack(spacing: 3) {
                    ForEach(Difficulty.allCases) { level in
                        Button(level.title) { difficulty = level.rawValue }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(difficulty == level.rawValue ? Color.black : Color.white)
                            .frame(width: 67, height: 28)
                            .background(difficulty == level.rawValue
                                        ? Color.cyan : Color(white: 0.28))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.white.opacity(0.38), lineWidth: 1))
                    }
                }
                .help("Difficulty: changing this starts a new game")
                HStack(spacing: 3) {
                    ForEach(Look.allCases) { look in
                        Button(look.title) { mode = look.rawValue }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(mode == look.rawValue ? Color.black : Color.white)
                            .frame(width: look == .classic ? 66 : 116, height: 28)
                            .background(mode == look.rawValue
                                        ? Color.cyan : Color(white: 0.28))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.white.opacity(0.38), lineWidth: 1))
                    }
                }
                Toggle("Sound", isOn: $soundEnabled)
                    .toggleStyle(.checkbox)
                Button("Scores") { showScores = true }
                Button("New Game") { game.restart() }
                    .keyboardShortcut("r", modifiers: [.command])
            }
            .padding(.horizontal, 18)
            .frame(height: 54)
            .background(Color(white: 0.10))
            GameView(scene: game)
                .background(.black)
            HStack {
                Text("← → Rotate    ↑ Thrust    Space Fire    S Shield    ↓ Warp    P Pause    R Restart")
                Spacer()
                Text("Click playfield for keyboard focus")
            }
            .font(.system(size: 11, design: .monospaced))
            .padding(12)
            .background(Color(white: 0.10))
        }
        .foregroundStyle(.white)
        .onAppear {
            game.modern = mode == Look.modern.rawValue
            game.difficulty = Difficulty(rawValue: difficulty) ?? .medium
            ArcadeAudio.shared.enabled = soundEnabled
        }
        .onChange(of: soundEnabled) { ArcadeAudio.shared.enabled = $0 }
        .sheet(isPresented: $showScores) {
            VStack(alignment: .leading, spacing: 14) {
                Text("LOCAL HIGH SCORES").font(.title2.monospaced().bold())
                ForEach(Difficulty.allCases) { level in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(level.title.uppercased()).font(.headline.monospaced())
                        let scores = UserDefaults.standard.array(forKey: "vectorDriftScores.\(level.rawValue)") as? [Int] ?? []
                        if scores.isEmpty {
                            Text("No completed runs yet").foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(scores.prefix(5).enumerated()), id: \.offset) { entry in
                                Text("\(entry.offset + 1).  \(entry.element)").font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                }
                Button("Close") { showScores = false }
            }
            .padding(26)
            .frame(minWidth: 360)
        }
        .onChange(of: mode) { value in game.modern = value == Look.modern.rawValue }
        .onChange(of: difficulty) { value in
            game.difficulty = Difficulty(rawValue: value) ?? .medium
            game.restart()
        }
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
    var detail: SKNode
    var hitPoints: Int
    let maximumHitPoints: Int
    var crack: SKShapeNode
    var secondCrack: SKShapeNode
    var lastShieldImpact: CGFloat
    /// nil means this asteroid has never been damaged.
    var fractureRemaining: CGFloat?
    var fractureDuration: CGFloat
    var fractureRing: SKShapeNode
}
private struct Laser {
    var node: SKShapeNode
    var velocity: CGVector
    var remaining: CGFloat
}

private struct Comet {
    var node: SKNode
    var velocity: CGVector
    var remaining: CGFloat
}

private struct Saucer {
    var node: SKShapeNode
    var velocity: CGVector
    var remaining: CGFloat
}

private struct EnemyShot {
    var node: SKShapeNode
    var velocity: CGVector
    var remaining: CGFloat
}

private struct Shockwave {
    var center: CGPoint
    var elapsed: CGFloat
    var ring: SKShapeNode
    var hit: Set<ObjectIdentifier>
}

final class DriftScene: SKScene {
    var modern = false { didSet { updateStyle() } }
    fileprivate var difficulty: Difficulty = .medium
    private var boulders: [Boulder] = []
    private var lasers: [Laser] = []
    private var comet: Comet?
    private var shockwaves: [Shockwave] = []
    private var lastComet: CGFloat = 0
    private var nextCometDelay: CGFloat = 13
    private var nextSpark: CGFloat = 0
    private var saucer: Saucer?
    private var enemyShots: [EnemyShot] = []
    private var lastSaucer: CGFloat = 0
    private var nextSaucerDelay: CGFloat = 20
    private var lastSaucerShot: CGFloat = 0
    private var titleVisible = true
    private var scoreRecorded = false
    private var shieldActive = false
    private var shieldEnergy: CGFloat = 0
    private let shieldNode = ArcadeEffects.shield()
    private var backgroundLayer: SKNode?
    private let modernShipDetail = ModernVisuals.shipDetail()
    private let flame = ModernVisuals.engineFlame()
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
        ship.addChild(modernShipDetail)
        ship.addChild(flame)
        ship.addChild(shieldNode)
        hud.fontSize = 15
        hud.horizontalAlignmentMode = .left
        hud.verticalAlignmentMode = .top
        addChild(hud)
        message.fontSize = 28
        message.horizontalAlignmentMode = .center
        addChild(message)
        showTitle()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        hud.position = CGPoint(x: 18, y: size.height - 18)
        message.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    func restart() {
        ArcadeAudio.shared.stopThrust()
        guard ready else { return }
        boulders.forEach { $0.node.removeFromParent() }
        lasers.forEach { $0.node.removeFromParent() }
        clearSpecialEffects()
        clearEnemies()
        boulders.removeAll()
        lasers.removeAll()
        held.removeAll()
        score = 0; lives = difficulty.startingLives; wave = 1
        elapsed = 0; lastTime = 0; lastFire = -2; lastWarp = -10
        stopped = false; over = false
        titleVisible = false
        scoreRecorded = false
        shieldActive = false
        shieldEnergy = difficulty.shieldDuration
        lastComet = 0
        nextCometDelay = CGFloat.random(in: difficulty.cometDelay)
        lastSaucer = 0
        nextSaucerDelay = CGFloat.random(in: difficulty.saucerDelay)
        lastSaucerShot = 0
        nextSpark = 0
        resetShip()
        protectedUntil = difficulty.respawnProtection
        ship.removeAllActions()
        ship.alpha = 1
        ship.setScale(1)
        ship.isHidden = false
        shieldNode.isHidden = true
        message.text = ""
        ArcadeAudio.shared.play(.wave)
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

    func clearKeys() {
        held.removeAll()
        ArcadeAudio.shared.stopThrust()
    }

    private func showTitle() {
        ArcadeAudio.shared.stopThrust()
        titleVisible = true
        over = false
        message.text = "VECTOR DRIFT · PRESS RETURN"
        message.position = CGPoint(x: size.width / 2, y: size.height / 2)
        updateHud()
        updateStyle()
    }

    func key(_ code: UInt16, down: Bool, isRepeat: Bool) {
        if down { held.insert(code) } else { held.remove(code) }
        guard down && !isRepeat else { return }
        if titleVisible || over {
            if code == 36 || code == 49 || code == 15 { restart() }
            return
        }
        switch code {
        case 1: // S toggles a finite energy reservoir, refilled on each wave.
            guard !stopped, shieldEnergy > 0 else { break }
            shieldActive.toggle()
            shieldNode.isHidden = !shieldActive
            ArcadeAudio.shared.play(.shield)
        case 35: // P
            if !over {
                stopped.toggle()
                if stopped { ArcadeAudio.shared.stopThrust() }
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
        guard ready && !over && !stopped && !titleVisible else {
            ArcadeAudio.shared.stopThrust()
            return
        }
        elapsed += dt
        if shieldActive {
            shieldEnergy = max(0, shieldEnergy - dt)
            if shieldEnergy == 0 {
                shieldActive = false
                shieldNode.isHidden = true
            }
        }
        ArcadeEffects.updateShield(shieldNode, modern: modern,
                                   remaining: shieldActive ? shieldEnergy : 0,
                                   total: difficulty.shieldDuration)
        updateHud()

        if held.contains(123) { heading += 3.7 * dt }
        if held.contains(124) { heading -= 3.7 * dt }
        let forward = CGVector(dx: -sin(heading), dy: cos(heading))
        let thrusting = held.contains(126) && !ship.isHidden
        ArcadeAudio.shared.setThrust(thrusting)
        if thrusting {
            velocity.dx += forward.dx * 265 * dt
            velocity.dy += forward.dy * 265 * dt
            let speed = hypot(velocity.dx, velocity.dy)
            if speed > 440 { velocity.dx *= 440 / speed; velocity.dy *= 440 / speed }
        }
        ship.zRotation = heading
        flame.isHidden = !modern || !thrusting
        flame.yScale = CGFloat.random(in: 0.75...1.25)
        ship.position = wrapped(CGPoint(x: ship.position.x + velocity.dx * dt,
                                        y: ship.position.y + velocity.dy * dt), margin: 15)
        ship.alpha = elapsed < protectedUntil && Int(elapsed * 10).isMultiple(of: 2) ? 0.25 : 1

        if held.contains(49) && elapsed - lastFire > difficulty.shootCooldown && lasers.count < 6 {
            lastFire = elapsed
            ArcadeAudio.shared.play(.fire)
            let bullet = SKShapeNode(circleOfRadius: 2)
            bullet.position = CGPoint(x: ship.position.x + forward.dx * 20,
                                      y: ship.position.y + forward.dy * 20)
            bullet.fillColor = .white
            addChild(bullet)
            lasers.append(Laser(node: bullet,
                                velocity: CGVector(dx: velocity.dx + forward.dx * 540,
                                                   dy: velocity.dy + forward.dy * 540),
                                remaining: difficulty.bulletLifetime))
        }

        for i in boulders.indices {
            boulders[i].node.position = wrapped(CGPoint(
                x: boulders[i].node.position.x + boulders[i].velocity.dx * dt,
                y: boulders[i].node.position.y + boulders[i].velocity.dy * dt),
                margin: boulders[i].radius)
            boulders[i].node.zRotation += boulders[i].spin * dt
        }
        // Only previously damaged multi-hit asteroids can self-fracture.
        // Using game dt means these timers pause along with the game.
        for index in boulders.indices.reversed() {
            guard let remaining = boulders[index].fractureRemaining else { continue }
            let updated = remaining - dt
            if updated <= 0 {
                fragmentRock(at: index, byPlayer: false)
            } else {
                boulders[index].fractureRemaining = updated
                updateFractureIndicator(at: index)
            }
        }
        // Shield contact reflects incoming asteroids instead of merely allowing
        // them to overlap the protected ship. It does not destroy the rock.
        if shieldActive && !ship.isHidden {
            bounceShieldAsteroids()
        }

        for i in lasers.indices {
            lasers[i].remaining -= dt
            lasers[i].node.position = wrapped(CGPoint(
                x: lasers[i].node.position.x + lasers[i].velocity.dx * dt,
                y: lasers[i].node.position.y + lasers[i].velocity.dy * dt), margin: 0)
        }

        if modern || difficulty == .hard {
            updateComet(dt)
            updateShockwaves(dt)
        }
        updateSaucer(dt)
        updateEnemyShots(dt)
        for i in lasers.indices.reversed() {
            if lasers[i].remaining <= 0 {
                lasers.remove(at: i).node.removeFromParent()
                continue
            }
            if let activeComet = comet,
                hypot(activeComet.node.position.x - lasers[i].node.position.x,
                      activeComet.node.position.y - lasers[i].node.position.y) < 22 {
                lasers.remove(at: i).node.removeFromParent()
                detonateComet(at: activeComet.node.position)
                continue
            }
            if let activeSaucer = saucer,
               hypot(activeSaucer.node.position.x - lasers[i].node.position.x,
                     activeSaucer.node.position.y - lasers[i].node.position.y) < 26 {
                lasers.remove(at: i).node.removeFromParent()
                destroySaucer()
                continue
            }
            if let j = boulders.firstIndex(where: {
                hypot($0.node.position.x - lasers[i].node.position.x,
                      $0.node.position.y - lasers[i].node.position.y) < $0.radius + 2
            }) {
                lasers.remove(at: i).node.removeFromParent()
                if boulders[j].hitPoints > 1 {
                    boulders[j].hitPoints -= 1
                    let rock = boulders[j]
                    let damageStage = rock.maximumHitPoints - rock.hitPoints
                    // First hit: 10s. Second nonfatal hit: 5s. An
                    // extra hit never extends an existing countdown.
                    let countdown = CGFloat(10) / CGFloat(damageStage)
                    boulders[j].fractureRemaining = min(
                        rock.fractureRemaining ?? countdown, countdown
                    )
                    boulders[j].fractureDuration = countdown
                    rock.crack.isHidden = false
                    rock.secondCrack.isHidden = damageStage < 2
                    rock.node.lineWidth = damageStage == 1 ? 3 : 3.8
                    rock.node.strokeColor = modern
                        ? (damageStage == 1 ? ModernVisuals.fire : .systemRed)
                        : (damageStage == 1 ? .yellow : .orange)
                    ArcadeAudio.shared.play(.rock)
                    updateFractureIndicator(at: j)
                    if modern {
                        ModernVisuals.damageFlare(in: self, at: rock.node.position,
                                                  radius: rock.radius, stage: damageStage)
                    }
                    continue // No change in radius until final shot or countdown.
                }
                fragmentRock(at: j, byPlayer: true)
            }
        }

        if elapsed >= protectedUntil && !ship.isHidden && !shieldActive &&
            (boulders.contains(where: {
                hypot($0.node.position.x - ship.position.x,
                      $0.node.position.y - ship.position.y) < $0.radius + 11
            }) || enemyShots.contains(where: {
                hypot($0.node.position.x - ship.position.x,
                      $0.node.position.y - ship.position.y) < 15
            }) || (saucer.map {
                hypot($0.node.position.x - ship.position.x,
                      $0.node.position.y - ship.position.y) < 34
            } ?? false)) {
            lives -= 1
            ArcadeAudio.shared.stopThrust()
            shieldActive = false
            shieldNode.isHidden = true
            ArcadeAudio.shared.play(.ship)
            shipImpact()
            updateHud()
            if lives <= 0 {
                over = true
                ship.isHidden = true
                saveFinalScore()
                message.text = "GAME OVER · PRESS RETURN"
            } else {
                resetShip()
                protectedUntil = elapsed + difficulty.respawnProtection
            }
        }
        if boulders.isEmpty && shockwaves.isEmpty {
            wave += 1
            shieldEnergy = difficulty.shieldDuration
            shieldActive = false
            shieldNode.isHidden = true
            spawnWave()
            ArcadeAudio.shared.play(.wave)
            protectedUntil = elapsed + 1.5
            updateHud()
        }
    }

    /// Detects the shield's outer radius and redirects each rock's relative
    /// velocity outward along the contact normal. Separation prevents repeated
    /// collision sounds or rocks sticking to the shield.
    private func bounceShieldAsteroids() {
        let shieldRadius: CGFloat = 32
        for index in boulders.indices {
            let rock = boulders[index]
            let dx = rock.node.position.x - ship.position.x
            let dy = rock.node.position.y - ship.position.y
            let distance = hypot(dx, dy)
            let minimumDistance = shieldRadius + rock.radius
            guard distance < minimumDistance else { continue }

            // When centers coincide, choose a stable normal along the ship's nose.
            let normalX = distance > 0.001 ? dx / distance : -sin(heading)
            let normalY = distance > 0.001 ? dy / distance : cos(heading)
            rock.node.position = CGPoint(
                x: ship.position.x + normalX * (minimumDistance + 1),
                y: ship.position.y + normalY * (minimumDistance + 1)
            )

            let relativeX = rock.velocity.dx - velocity.dx
            let relativeY = rock.velocity.dy - velocity.dy
            let approach = relativeX * normalX + relativeY * normalY
            guard approach < 0 else { continue }

            // Restitution is slightly greater than one for satisfying arcade bounce.
            let restitution: CGFloat = 1.10
            let reflectedX = relativeX - (1 + restitution) * approach * normalX
            let reflectedY = relativeY - (1 + restitution) * approach * normalY
            boulders[index].velocity = CGVector(
                dx: velocity.dx + reflectedX,
                dy: velocity.dy + reflectedY
            )
            // Larger rock masses transfer a more substantial recoil to
            // the shielded ship without consuming shield energy on impact.
            let impactSpeed = -approach
            let massFactor: CGFloat = rock.level == 5 ? 0.42 :
                                      rock.level == 4 ? 0.30 :
                                      rock.level == 3 ? 0.22 : 0.12
            let recoil = min(95, impactSpeed * massFactor)
            velocity.dx -= normalX * recoil
            velocity.dy -= normalY * recoil
            let shipSpeed = hypot(velocity.dx, velocity.dy)
            if shipSpeed > 440 {
                velocity.dx *= 440 / shipSpeed
                velocity.dy *= 440 / shipSpeed
            }

            if elapsed - rock.lastShieldImpact > 0.12 {
                boulders[index].lastShieldImpact = elapsed
                let hitPoint = CGPoint(
                    x: ship.position.x + normalX * shieldRadius,
                    y: ship.position.y + normalY * shieldRadius
                )
                shieldImpact(at: hitPoint, rockLevel: rock.level)
                ArcadeAudio.shared.play(.bounce)
            }
        }
    }

    private func shieldImpact(at point: CGPoint, rockLevel: Int) {
        // The shield visibly compresses and rebounds when struck. Animating
        // the outer ring (not the parent node) leaves its idle pulse intact.
        if let outline = shieldNode.childNode(withName: "shieldOutline") {
            outline.removeAction(forKey: "impactFlex")
            let compression: CGFloat = rockLevel >= 4 ? 0.82 : 0.92
            outline.run(.sequence([
                .scale(to: compression, duration: 0.07),
                .scale(to: 1.08, duration: 0.13),
                .scale(to: 1, duration: 0.15)
            ]), withKey: "impactFlex")
        }
        let radius = CGFloat(6 + rockLevel * 2)
        let ripple = SKShapeNode(circleOfRadius: radius)
        ripple.position = point
        ripple.strokeColor = modern ? ModernVisuals.ice : .white
        ripple.fillColor = .clear
        ripple.lineWidth = rockLevel >= 4 ? 3.5 : 2
        ripple.glowWidth = modern ? CGFloat(6 + rockLevel * 2) : 0
        ripple.zPosition = 11
        addChild(ripple)
        ripple.run(.sequence([
            .group([.scale(to: rockLevel >= 4 ? 3.6 : 2.8, duration: 0.34),
                    .fadeOut(withDuration: 0.34)]),
            .removeFromParent()
        ]))
        if modern {
            ModernVisuals.burst(in: self, at: point, color: ModernVisuals.ice,
                                count: 4 + rockLevel * 4)
        }
    }

    private func hyperspace() {
        guard elapsed - lastWarp > difficulty.hyperspaceCooldown else { return }
        lastWarp = elapsed
        ship.position = CGPoint(x: .random(in: 40...max(41, size.width - 40)),
                                y: .random(in: 40...max(41, size.height - 40)))
        velocity = .zero
        protectedUntil = elapsed + 1.4
    }

    private func spawnWave() {
        for index in 0..<difficulty.rockCount(forWave: wave) {
            let level = difficulty.startingRockLevel(at: index)
            let radius = rockRadius(for: level)
            // The larger tiers require extra separation from the player.
            let margin = max(40, radius + 8)
            var point = CGPoint.zero
            for _ in 0..<35 {
                point = CGPoint(
                    x: .random(in: margin...max(margin + 1, size.width - margin)),
                    y: .random(in: margin...max(margin + 1, size.height - margin))
                )
                if hypot(point.x - ship.position.x, point.y - ship.position.y) > radius + 145 {
                    break
                }
            }
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = rockSpeed(for: level)
            spawnRock(level: level, at: point,
                      velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed))
        }
    }

    // Large boulders drift, medium fragments move briskly, small fragments are fast.
    // Wave escalation and difficulty apply to every size without changing its ordering.
    private func rockSpeed(for level: Int) -> CGFloat {
        let baseRange: ClosedRange<CGFloat>
        switch level {
        case 5: baseRange = 12...23
        case 4: baseRange = 22...39
        case 3: baseRange = 36...68
        case 2: baseRange = 85...118
        default: baseRange = 138...190
        }
        let waveFactor = 1 + min(CGFloat(wave - 1) * 0.045, 0.45)
        return CGFloat.random(in: baseRange) * difficulty.speedMultiplier * waveFactor
    }

    /// A player shot and the delayed fracture use exactly the same
    /// split progression. Automatic fractures award no points.
    private func fragmentRock(at index: Int, byPlayer: Bool) {
        let rock = boulders.remove(at: index)
        let position = rock.node.position
        rock.node.removeFromParent()
        ArcadeAudio.shared.play(.rock)
        if modern {
            ModernVisuals.fractureBurst(in: self, at: position,
                                        radius: rock.radius, intensity: rock.level)
        }
        if byPlayer {
            award(rock.level == 5 ? 90 :
                  rock.level == 4 ? 60 :
                  rock.level == 3 ? 20 :
                  rock.level == 2 ? 50 : 100)
        }
        if rock.level > 1 {
            let travelAngle = atan2(rock.velocity.dy, rock.velocity.dx)
            let nextLevel = rock.level - 1
            for spread: CGFloat in [-0.75, 0.75] {
                let angle = travelAngle + spread
                let speed = rockSpeed(for: nextLevel)
                spawnRock(level: nextLevel, at: position,
                          velocity: CGVector(dx: cos(angle) * speed,
                                             dy: sin(angle) * speed))
            }
        }
    }

    private func updateFractureIndicator(at index: Int) {
        let rock = boulders[index]
        guard let remaining = rock.fractureRemaining else {
            rock.fractureRing.isHidden = true
            return
        }
        let progress = max(0, min(1, remaining / max(rock.fractureDuration, 0.01)))
        if modern {
            let arc = CGMutablePath()
            arc.addArc(center: .zero, radius: rock.radius + 8,
                       startAngle: -.pi / 2,
                       endAngle: -.pi / 2 + 2 * .pi * progress,
                       clockwise: false)
            rock.fractureRing.path = arc
            rock.fractureRing.isHidden = false
            rock.fractureRing.strokeColor = progress < 0.3 ? .systemRed : ModernVisuals.fire
            rock.fractureRing.glowWidth = progress < 0.3 ? 12 : 5
        } else {
            rock.fractureRing.isHidden = true
        }
        if modern && progress < 0.25 {
            rock.node.glowWidth = 4 + 4 * abs(sin(elapsed * 9))
        }
    }

    private func rockRadius(for level: Int) -> CGFloat {
        switch level {
        case 5: return 96
        case 4: return 68
        case 3: return 43
        case 2: return 27
        default: return 15
        }
    }

    private func spawnRock(level: Int, at point: CGPoint, velocity: CGVector) {
        let radius = rockRadius(for: level)
        let path = CGMutablePath()
        var points: [CGPoint] = []
        let vertices = level == 5 ? 21 : level == 4 ? 17 : 12
        for i in 0..<vertices {
            let angle = 2 * CGFloat.pi * CGFloat(i) / CGFloat(vertices)
            let radiusVariation = CGFloat.random(in: 0.7...1.14)
            let vertex = CGPoint(x: cos(angle) * radius * radiusVariation,
                                 y: sin(angle) * radius * radiusVariation)
            points.append(vertex)
            if i == 0 { path.move(to: vertex) } else { path.addLine(to: vertex) }
        }
        path.closeSubpath()
        let node = SKShapeNode(path: path)
        node.position = point
        node.fillColor = .clear
        node.lineWidth = 1.7
        let detail = ModernVisuals.asteroidDetail(radius: radius, vertices: points)
        node.addChild(detail)
        let crack = ArcadeEffects.damageCrack(radius: radius)
        node.addChild(crack)
        let secondCrack = ArcadeEffects.damageCrack(radius: radius)
        secondCrack.zRotation = .pi * 0.73
        secondCrack.setScale(0.85)
        node.addChild(secondCrack)
        let fractureRing = SKShapeNode()
        fractureRing.lineWidth = 2.1
        fractureRing.fillColor = .clear
        fractureRing.zPosition = 6
        fractureRing.isHidden = true
        node.addChild(fractureRing)
        addChild(node)
        let hitPoints = difficulty.hitsToSplit(level: level)
        let spinSpeed = CGFloat.random(in: -1.2...1.2) /
            (1 + CGFloat(max(level - 3, 0)) * 0.5)
        boulders.append(Boulder(node: node, velocity: velocity, radius: radius,
                                level: level, spin: spinSpeed, detail: detail,
                                hitPoints: hitPoints, maximumHitPoints: hitPoints,
                                crack: crack, secondCrack: secondCrack,
                                lastShieldImpact: -10, fractureRemaining: nil,
                                fractureDuration: 0, fractureRing: fractureRing))
        styleRock(node, detail: detail)
    }

    private func updateHud() {
        hud.text = String(format: "SCORE %06d   HIGH %06d   WAVE %d   LIVES %d   %@   SHIELD %.1fs",
                          score, high, wave, lives, difficulty.title.uppercased(), shieldEnergy)
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
            styleRock(rock.node, detail: rock.detail)
            let damageStage = rock.maximumHitPoints - rock.hitPoints
            if damageStage > 0 {
                rock.node.lineWidth = damageStage == 1 ? 3 : 3.8
                rock.node.strokeColor = modern
                    ? (damageStage == 1 ? ModernVisuals.fire : .systemRed)
                    : (damageStage == 1 ? .yellow : .orange)
            } else {
                rock.node.lineWidth = 1.7
            }
            rock.crack.isHidden = damageStage == 0
            rock.secondCrack.isHidden = damageStage < 2
            rock.crack.strokeColor = modern ? ModernVisuals.fire : .yellow
            rock.secondCrack.strokeColor = modern ? .systemRed : .orange
            if rock.fractureRemaining != nil {
                rock.fractureRing.isHidden = !modern
            }
        }
        ArcadeEffects.updateShield(shieldNode, modern: modern,
                                   remaining: shieldActive ? shieldEnergy : 0,
                                   total: difficulty.shieldDuration)
        if let saucer {
            saucer.node.strokeColor = modern ? .systemPink : .white
            saucer.node.glowWidth = modern ? 8 : 0
        }
        modernShipDetail.isHidden = !modern
        flame.isHidden = true
        backgroundLayer?.removeFromParent()
        backgroundLayer = nil
        if modern {
            let layer = ModernVisuals.backdrop(size: size)
            addChild(layer)
            backgroundLayer = layer
        } else {
            // Comets and shockwaves remain in Classic on Hard difficulty.
            if difficulty != .hard {
                comet?.node.removeFromParent()
                comet = nil
            }
        }
        for laser in lasers {
            laser.node.fillColor = modern ? .yellow : .white
            laser.node.strokeColor = laser.node.fillColor
        }
    }

    private func styleRock(_ node: SKShapeNode, detail: SKNode) {
        detail.isHidden = !modern
        node.strokeColor = modern ? ModernVisuals.ice : .white
        node.fillColor = modern ? ModernVisuals.rock : .clear
        node.glowWidth = modern ? 5 : 0
    }

    private func award(_ amount: Int) {
        score += amount
        if score > high {
            high = score
            UserDefaults.standard.set(high, forKey: "highScore")
        }
        updateHud()
    }

    private func clearSpecialEffects() {
        comet?.node.removeFromParent()
        comet = nil
        for wave in shockwaves { wave.ring.removeFromParent() }
        shockwaves.removeAll()
        children.filter { $0.name == "modernEffect" }.forEach { $0.removeFromParent() }
    }

    /// A short yellow impact flash and an original ship-breaking animation.
    /// Both effects are implemented with SpriteKit shapes; no external art assets.
    private func shipImpact() {
        let position = ship.position

        let flash = SKShapeNode(rectOf: CGSize(width: max(size.width, 1),
                                                height: max(size.height, 1)))
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.fillColor = modern
            ? SKColor(calibratedRed: 1, green: 0.57, blue: 0.16, alpha: 0.52)
            : SKColor(calibratedRed: 1, green: 0.91, blue: 0.10, alpha: 0.68)
        flash.strokeColor = .clear
        flash.zPosition = 50
        addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.21), .removeFromParent()]))

        ship.isHidden = true
        let shards: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 0, y: 19), CGPoint(x: -12, y: -12)),
            (CGPoint(x: -12, y: -12), CGPoint(x: 0, y: -7)),
            (CGPoint(x: 0, y: -7), CGPoint(x: 12, y: -12)),
            (CGPoint(x: 12, y: -12), CGPoint(x: 0, y: 19))
        ]
        for (start, end) in shards {
            let p = CGMutablePath()
            p.move(to: start)
            p.addLine(to: end)
            let fragment = SKShapeNode(path: p)
            fragment.position = position
            fragment.zRotation = heading
            fragment.strokeColor = modern ? ModernVisuals.fire : .yellow
            fragment.lineWidth = 2.5
            fragment.glowWidth = modern ? 8 : 1
            fragment.zPosition = 12
            addChild(fragment)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let duration = Double.random(in: 0.55...0.9)
            let distance = CGFloat.random(in: 40...130)
            fragment.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * distance,
                            y: sin(angle) * distance, duration: duration),
                    .rotate(byAngle: CGFloat.random(in: -5...5), duration: duration),
                    .fadeOut(withDuration: duration)
                ]),
                .removeFromParent()
            ]))
        }
        if modern {
            ModernVisuals.burst(in: self, at: position,
                                color: ModernVisuals.fire, count: 22)
        }
        if lives > 0 {
            ship.run(.sequence([.wait(forDuration: 0.85), .run { [weak self] in
                guard let self, !self.over else { return }
                self.ship.isHidden = false
            }]))
        }
    }

    private func updateComet(_ dt: CGFloat) {
        if comet == nil && wave >= 2 && elapsed - lastComet >= nextCometDelay {
            spawnComet()
        }
        guard var active = comet else { return }
        active.remaining -= dt
        active.node.position.x += active.velocity.dx * dt
        active.node.position.y += active.velocity.dy * dt

        if elapsed >= nextSpark {
            nextSpark = elapsed + 0.075
            if modern {
                ModernVisuals.cometSpark(in: self, at: active.node.position,
                                         direction: active.velocity)
            }
        }

        if active.remaining <= 0 ||
           active.node.position.x < -300 ||
           active.node.position.x > size.width + 300 {
            active.node.removeFromParent()
            comet = nil
            lastComet = elapsed
            nextCometDelay = CGFloat.random(in: difficulty.cometDelay)
        } else {
            comet = active
        }
    }

    private func spawnComet() {
        let fromLeft = Bool.random()
        let direction: CGFloat = fromLeft ? 1 : -1
        let node = modern ? ModernVisuals.cometNode() : ArcadeEffects.classicComet()
        node.position = CGPoint(
            x: fromLeft ? -45 : size.width + 45,
            y: CGFloat.random(in: (size.height * 0.16)...(size.height * 0.84))
        )
        let vy = CGFloat.random(in: -34...34)
        let speed = CGFloat.random(in: 180...235) * difficulty.speedMultiplier
        let v = CGVector(dx: direction * speed, dy: vy)
        node.zRotation = atan2(vy, v.dx)
        addChild(node)
        comet = Comet(node: node, velocity: v, remaining: (size.width + 140) / speed + 1)
    }

    private func detonateComet(at point: CGPoint) {
        comet?.node.removeFromParent()
        comet = nil
        lastComet = elapsed
        nextCometDelay = CGFloat.random(in: difficulty.cometDelay)

        award(750)
        ArcadeAudio.shared.play(.comet)
        if modern {
            ModernVisuals.floatScore("COMET +750", in: self, at: point)
            ModernVisuals.burst(in: self, at: point, color: ModernVisuals.fire, count: 42)
        }

        let ring = ModernVisuals.shockRing(at: point)
        if !modern {
            ring.strokeColor = .white
            ring.glowWidth = 0
        }
        addChild(ring)
        shockwaves.append(Shockwave(center: point, elapsed: 0,
                                    ring: ring, hit: Set<ObjectIdentifier>()))
    }

    private func updateShockwaves(_ dt: CGFloat) {
        for i in shockwaves.indices.reversed() {
            shockwaves[i].elapsed += dt
            let progress = min(shockwaves[i].elapsed / 0.95, 1)
            let radius: CGFloat = 350 * progress
            shockwaves[i].ring.setScale(max(0.01, radius / 12))
            shockwaves[i].ring.alpha = 1 - progress

            for j in boulders.indices.reversed() {
                let rock = boulders[j]
                let identity = ObjectIdentifier(rock.node)
                guard !shockwaves[i].hit.contains(identity) else { continue }
                let distance = hypot(rock.node.position.x - shockwaves[i].center.x,
                                     rock.node.position.y - shockwaves[i].center.y)
                guard distance < radius + rock.radius else { continue }
                shockwaves[i].hit.insert(identity)
                let removed = boulders.remove(at: j)
                removed.node.removeFromParent()
                award(removed.level == 5 ? 180 :
                      removed.level == 4 ? 120 :
                      removed.level == 3 ? 40 :
                      removed.level == 2 ? 100 : 200)
                if modern {
                    ModernVisuals.burst(in: self, at: removed.node.position,
                                        color: ModernVisuals.ice, count: 11)
                }
            }

            if progress >= 1 {
                shockwaves.remove(at: i).ring.removeFromParent()
            }
        }
    }

    private func clearEnemies() {
        saucer?.node.removeFromParent()
        saucer = nil
        for shot in enemyShots { shot.node.removeFromParent() }
        enemyShots.removeAll()
    }

    private func updateSaucer(_ dt: CGFloat) {
        if saucer == nil && wave >= 2 && elapsed - lastSaucer > nextSaucerDelay {
            spawnSaucer()
        }
        guard var enemy = saucer else { return }
        enemy.remaining -= dt
        enemy.node.position.x += enemy.velocity.dx * dt
        enemy.node.position.y += sin(elapsed * 2.6) * 22 * dt
        if elapsed - lastSaucerShot > (difficulty == .hard ? 1.3 : difficulty == .medium ? 2.0 : 2.8) {
            lastSaucerShot = elapsed
            fireSaucerShot(from: enemy.node.position)
            ArcadeAudio.shared.play(.saucer)
        }
        if enemy.remaining <= 0 || enemy.node.position.x < -65 ||
           enemy.node.position.x > size.width + 65 {
            enemy.node.removeFromParent()
            saucer = nil
            lastSaucer = elapsed
            nextSaucerDelay = CGFloat.random(in: difficulty.saucerDelay)
        } else {
            saucer = enemy
        }
    }

    private func spawnSaucer() {
        let fromLeft = Bool.random()
        let direction: CGFloat = fromLeft ? 1 : -1
        let node = ArcadeEffects.saucer(modern: modern)
        node.position = CGPoint(x: fromLeft ? -40 : size.width + 40,
                                y: CGFloat.random(in: (size.height * 0.25)...(size.height * 0.85)))
        addChild(node)
        let speed = CGFloat.random(in: 72...108) * difficulty.speedMultiplier
        saucer = Saucer(node: node, velocity: CGVector(dx: direction * speed, dy: 0),
                        remaining: (size.width + 120) / speed + 1)
        lastSaucerShot = elapsed
    }

    private func fireSaucerShot(from origin: CGPoint) {
        let aim = atan2(ship.position.y - origin.y, ship.position.x - origin.x)
        let spread = CGFloat.random(in: difficulty == .easy ? -0.65...0.65 : difficulty == .hard ? -0.09...0.09 : -0.33...0.33)
        let angle = aim + spread
        let speed: CGFloat = difficulty == .hard ? 240 : difficulty == .medium ? 195 : 160
        let bullet = SKShapeNode(circleOfRadius: 3)
        bullet.position = origin
        bullet.fillColor = modern ? .systemPink : .white
        bullet.strokeColor = .clear
        bullet.glowWidth = modern ? 6 : 0
        bullet.zPosition = 4
        addChild(bullet)
        enemyShots.append(EnemyShot(node: bullet,
                                    velocity: CGVector(dx: cos(angle) * speed,
                                                       dy: sin(angle) * speed),
                                    remaining: 2.7))
    }

    private func updateEnemyShots(_ dt: CGFloat) {
        for i in enemyShots.indices.reversed() {
            enemyShots[i].remaining -= dt
            enemyShots[i].node.position = wrapped(
                CGPoint(x: enemyShots[i].node.position.x + enemyShots[i].velocity.dx * dt,
                        y: enemyShots[i].node.position.y + enemyShots[i].velocity.dy * dt),
                margin: 0)
            if enemyShots[i].remaining <= 0 {
                enemyShots.remove(at: i).node.removeFromParent()
            }
        }
    }

    private func destroySaucer() {
        guard let enemy = saucer else { return }
        let position = enemy.node.position
        enemy.node.removeFromParent()
        saucer = nil
        lastSaucer = elapsed
        nextSaucerDelay = CGFloat.random(in: difficulty.saucerDelay)
        award(200)
        ArcadeAudio.shared.play(.saucer)
        if modern {
            ModernVisuals.burst(in: self, at: position, color: .systemPink, count: 20)
            ModernVisuals.floatScore("+200", in: self, at: position)
        }
    }

    private func saveFinalScore() {
        guard !scoreRecorded else { return }
        scoreRecorded = true
        guard score > 0 else { return }
        let key = "vectorDriftScores.\(difficulty.rawValue)"
        var scores = UserDefaults.standard.array(forKey: key) as? [Int] ?? []
        scores.append(score)
        scores.sort(by: >)
        UserDefaults.standard.set(Array(scores.prefix(5)), forKey: key)
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
