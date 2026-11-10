import AppKit
import SceneKit
import SwiftUI

struct SavedVector3D: Codable {
    var x: Double
    var y: Double
    var z: Double
}

struct SavedRock3D: Codable {
    var level: Int
    var position: SavedVector3D
    var velocity: SavedVector3D
    var health: Int
    var fractureRemaining: Double?
}

struct SavedShot3D: Codable {
    var position: SavedVector3D
    var velocity: SavedVector3D
    var remaining: Double
}

struct Flight3DSnapshot: Codable {
    var difficulty: String
    var customRules: GameRules?
    var score: Int
    var lives: Int
    var wave: Int
    var elapsed: Double
    var yaw: Double
    var pitch: Double
    var roll: Double
    var shipPosition: SavedVector3D
    var shipVelocity: SavedVector3D
    var protectionRemaining: Double
    var shieldActive: Bool
    var shieldRemaining: Double
    var shieldRechargeRemaining: Double
    var lastShotAgo: Double
    var ammoReserve: AmmoReserve?
    var beamBattery: BeamBattery?
    var missilesRemaining: Int
    var missile: SavedShot3D?
    var rocks: [SavedRock3D]
    var shots: [SavedShot3D]
    var blackHolePosition: SavedVector3D?
    var blackHoleRemaining: Double
    var lastBlackHoleAgo: Double
    var nextBlackHoleDelay: Double
}

struct Flight3DSaveSlot: Codable, Identifiable {
    var id: String
    var date: Date
    var summary: String
    var snapshot: Flight3DSnapshot
}

enum Flight3DStore {
    private static let key = "vectorDrift.3dSaves.v1"
    static func saves() -> [Flight3DSaveSlot] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([Flight3DSaveSlot].self, from: data) else {
            return []
        }
        return list
    }
    static func save(_ snapshot: Flight3DSnapshot) {
        let slot = Flight3DSaveSlot(id: UUID().uuidString, date: Date(),
             summary: "3D Flight · Wave \(snapshot.wave) · \(snapshot.score) points",
             snapshot: snapshot)
        var list = saves()
        list.insert(slot, at: 0)
        if let data = try? JSONEncoder().encode(Array(list.prefix(12))) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    static func delete(id: String) {
        let list = saves().filter { $0.id != id }
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// Independent fully spatial arena. Ship, projectiles and rocks all use
/// real three-dimensional positions and velocities (not 2D billboards).
struct Flight3DView: NSViewRepresentable {
    let game: Flight3DGame

    func makeNSView(context: Context) -> Flight3DSceneView {
        let view = Flight3DSceneView()
        view.backgroundColor = .black
        view.allowsCameraControl = false
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        view.scene = game.scene
        view.pointOfView = game.camera
        view.game = game
        view.delegate = game
        return view
    }

    func updateNSView(_ view: Flight3DSceneView, context: Context) {
        if view.scene !== game.scene {
            view.scene = game.scene
            view.pointOfView = game.camera
            view.delegate = game
        }
        view.game = game
    }
}

final class Flight3DSceneView: SCNView {
    weak var game: Flight3DGame?
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        game?.key(event.keyCode, pressed: true, repeatKey: event.isARepeat)
    }

    override func keyUp(with event: NSEvent) {
        game?.key(event.keyCode, pressed: false, repeatKey: false)
    }

    override func flagsChanged(with event: NSEvent) {
        game?.setShiftActive(event.modifierFlags.contains(.shift))
        super.flagsChanged(with: event)
    }

    override func resignFirstResponder() -> Bool {
        game?.clearKeys()
        return super.resignFirstResponder()
    }
}

private struct SpaceRock3D {
    let node: SCNNode
    var velocity: SCNVector3
    var level: Int
    var health: Int
    var fractureTime: CGFloat?
}
private struct SpaceShot3D {
    let node: SCNNode
    var velocity: SCNVector3
    var remaining: CGFloat
}
private struct NuclearMissile3D {
    let node: SCNNode
    var velocity: SCNVector3
    var fuse: CGFloat
}

final class Flight3DGame: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    let ship = SCNNode()
    let camera = SCNNode()
    private var rocks: [SpaceRock3D] = []
    private var shots: [SpaceShot3D] = []
    private var nuclearMissile: NuclearMissile3D?
    private var missilesRemaining = 2
    private var blackHole: SCNNode?
    private var blackHoleRemaining: CGFloat = 0
    private var lastBlackHole: CGFloat = 0
    private var nextBlackHoleDelay: CGFloat = 29
    private var pressed = Set<UInt16>()
    private var previous: TimeInterval = 0
    private var elapsed: CGFloat = 0
    private var lastShot: CGFloat = -2
    private var ammo = AmmoReserve()
    private var beamBattery = BeamBattery()
    private var shiftHeld = false
    private var lastBeamFire: CGFloat = -2
    private var invulnerableUntil: CGFloat = 0
    private var shipVelocity = SCNVector3Zero
    private var yaw: CGFloat = 0
    private var pitch: CGFloat = 0
    private var roll: CGFloat = 0
    private var score = 0
    private var lives = 3
    private var wave = 1
    private var gameOver = false
    private var paused = false
    private var shieldActive = false
    private var shieldRemaining: CGFloat = 5
    private var shieldCooldownRemaining: CGFloat = 0
    private let shield = SCNNode()
    private let headlight = SCNNode()
    private let overlay = SCNNode()
    private let scoreLabel = SCNNode()
    private var message: String = ""
    private let boundary: CGFloat = 135

    var difficulty = "medium" {
        didSet { restart() }
    }
    var customRules: GameRules? {
        didSet { restart() }
    }
    var soundEnabled = true

    override init() {
        super.init()
        configureScene()
        restart()
    }

    private var rules: GameRules {
        customRules?.validated() ?? GameRules.defaults(for: difficulty)
    }

    private func configureScene() {
        scene.background.contents = NSColor(calibratedRed: 0.006, green: 0.014, blue: 0.038, alpha: 1)
        let atmosphere = SCNNode()
        scene.rootNode.addChildNode(atmosphere)

        for index in 0..<320 {
            let star = SCNNode(geometry: SCNSphere(radius: index.isMultiple(of: 8) ? 0.15 : 0.075))
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = NSColor(
                calibratedRed: CGFloat.random(in: 0.6...1),
                green: CGFloat.random(in: 0.76...1),
                blue: 1, alpha: 1
            )
            mat.emission.contents = mat.diffuse.contents
            star.geometry?.materials = [mat]
            star.position = SCNVector3(
                CGFloat.random(in: -170...170),
                CGFloat.random(in: -170...170),
                CGFloat.random(in: -170...170)
            )
            atmosphere.addChildNode(star)
        }

        // A custom low-poly fighter with a clearly defined forward direction (-Z).
        let hull = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.92, height: 3.4))
        hull.eulerAngles.x = -.pi / 2
        hull.geometry?.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.20, green: 0.72, blue: 0.92, alpha: 1)
        hull.geometry?.firstMaterial?.metalness.contents = 0.65
        hull.geometry?.firstMaterial?.roughness.contents = 0.25
        ship.addChildNode(hull)

        for direction: CGFloat in [-1, 1] {
            let wing = SCNNode(geometry: SCNBox(width: 2.2, height: 0.12, length: 1.15, chamferRadius: 0.08))
            wing.position = SCNVector3(direction * 1.05, -0.20, 0.65)
            wing.eulerAngles.z = direction * 0.13
            wing.geometry?.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.12, green: 0.42, blue: 0.57, alpha: 1)
            wing.geometry?.firstMaterial?.metalness.contents = 0.75
            ship.addChildNode(wing)
        }

        let engine = SCNNode(geometry: SCNSphere(radius: 0.28))
        engine.position.z = 1.75
        engine.geometry?.firstMaterial?.lightingModel = .constant
        engine.geometry?.firstMaterial?.emission.contents = NSColor.orange
        ship.addChildNode(engine)

        shield.geometry = SCNSphere(radius: 2.65)
        let sm = SCNMaterial()
        sm.diffuse.contents = NSColor(calibratedRed: 0.05, green: 0.65, blue: 1, alpha: 0.15)
        sm.emission.contents = NSColor(calibratedRed: 0.05, green: 0.27, blue: 0.6, alpha: 0.25)
        sm.transparency = 0.27
        sm.isDoubleSided = true
        sm.fillMode = .lines
        shield.geometry?.materials = [sm]
        shield.isHidden = true
        ship.addChildNode(shield)

        camera.camera = SCNCamera()
        camera.camera?.zNear = 0.1
        camera.camera?.zFar = 600
        camera.camera?.fieldOfView = 72
        camera.position = SCNVector3(0, 3.2, 12)
        camera.eulerAngles.x = -.pi * 0.07
        ship.addChildNode(camera)
        scene.rootNode.addChildNode(ship)

        headlight.light = SCNLight()
        headlight.light?.type = .omni
        headlight.light?.intensity = 800
        headlight.light?.color = NSColor(calibratedRed: 0.60, green: 0.83, blue: 1, alpha: 1)
        headlight.position = SCNVector3(0, 1.5, -5)
        ship.addChildNode(headlight)

        let distant = SCNNode()
        distant.light = SCNLight()
        distant.light?.type = .directional
        distant.light?.intensity = 900
        distant.eulerAngles = SCNVector3(-CGFloat.pi / 3, -CGFloat.pi / 5, 0)
        scene.rootNode.addChildNode(distant)
        scene.lightingEnvironment.intensity = 0.38
    }

    func restart() {
        // Xcode/SwiftUI invokes these on the main thread.
        for rock in rocks { rock.node.removeFromParentNode() }
        for shot in shots { shot.node.removeFromParentNode() }
        rocks.removeAll()
        shots.removeAll()
        nuclearMissile?.node.removeFromParentNode()
        nuclearMissile = nil
        blackHole?.removeFromParentNode()
        blackHole = nil
        blackHoleRemaining = 0
        lastBlackHole = 0
        nextBlackHoleDelay = CGFloat.random(in: 25...39)
        missilesRemaining = rules.missilesPerWave
        pressed.removeAll()
        ship.position = SCNVector3Zero
        ship.eulerAngles = SCNVector3Zero
        yaw = 0; pitch = 0; roll = 0
        shipVelocity = SCNVector3Zero
        score = 0
        lives = rules.startingLives
        wave = 1
        elapsed = 0
        previous = 0
        lastShot = -2
        ammo = AmmoReserve()
        beamBattery = BeamBattery()
        lastBeamFire = -2
        shiftHeld = false
        paused = false
        gameOver = false
        shieldActive = false
        shieldRemaining = CGFloat(rules.shieldDuration)
        shieldCooldownRemaining = 0
        shield.isHidden = true
        invulnerableUntil = 2
        message = ""
        spawnWave()
    }

    func clearKeys() {
        pressed.removeAll()
        shiftHeld = false
    }
    func setShiftActive(_ active: Bool) {
        shiftHeld = active
    }

    func key(_ code: UInt16, pressed down: Bool, repeatKey: Bool) {
        if down { pressed.insert(code) } else { pressed.remove(code) }
        guard down && !repeatKey else { return }
        switch code {
        case 45: if !paused { launchNuclearMissile() } // N
        case 35: paused.toggle() // P
        case 15: restart() // R
        case 1: // S
            if !shieldActive && shieldCooldownRemaining == 0 && !gameOver {
                shieldActive = true
                shieldRemaining = CGFloat(rules.shieldDuration)
                shield.isHidden = false
            } else if shieldActive {
                stopShield()
            }
        default: break
        }
    }

    private func stopShield() {
        shieldActive = false
        shield.isHidden = true
        shieldCooldownRemaining = CGFloat(rules.shieldCooldown)
    }

    private func speed(for level: Int) -> CGFloat {
        let base: CGFloat = [0, 28, 20, 15, 10, 7][min(5, max(1, level))]
        return base * CGFloat(rules.asteroidSpeed)
    }

    private func spawnWave() {
        let number = min(28, rules.rockCount(wave: wave))
        for i in 0..<number {
            let level = rules.initialRockLevel(at: i)
            let point = SCNVector3(
                CGFloat.random(in: -100...100),
                CGFloat.random(in: -65...65),
                CGFloat.random(in: -115...(-32))
            )
            let speed = speed(for: level)
            let motion = normalize(SCNVector3(
                CGFloat.random(in: -1...1), CGFloat.random(in: -1...1), CGFloat.random(in: -1...1)
            ))
            addRock(level: level, at: point, velocity: multiply(motion, speed))
        }
    }

    private func addRock(level: Int, at point: SCNVector3, velocity: SCNVector3,
                         health overrideHealth: Int? = nil, timer: CGFloat? = nil) {
        let radius: CGFloat = CGFloat([0, 0.9, 1.65, 2.8, 4.4, 6.3][min(5, max(1, level))])
        let shape = SCNSphere(radius: radius)
        shape.segmentCount = level >= 4 ? 9 : 7
        let palette: [NSColor] = [
            NSColor(calibratedRed: 0.12, green: 0.21, blue: 0.28, alpha: 1),
            NSColor(calibratedRed: 0.24, green: 0.31, blue: 0.35, alpha: 1),
            NSColor(calibratedRed: 0.40, green: 0.47, blue: 0.51, alpha: 1)
        ]
        let material = SCNMaterial()
        material.diffuse.contents = palette[level % palette.count]
        material.roughness.contents = 0.88
        material.metalness.contents = 0.06
        shape.firstMaterial = material
        let node = SCNNode(geometry: shape)
        node.position = point
        node.eulerAngles = SCNVector3(CGFloat.random(in: 0...(.pi)), CGFloat.random(in: 0...(.pi)), 0)
        scene.rootNode.addChildNode(node)
        rocks.append(SpaceRock3D(node: node, velocity: velocity, level: level,
                                 health: overrideHealth ?? rules.hits(level: level, difficulty: difficulty),
                                 fractureTime: timer))
    }

    private func fire() {
        let geometry = SCNSphere(radius: 0.22)
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = NSColor.cyan
        material.emission.contents = NSColor.cyan
        geometry.firstMaterial = material
        let node = SCNNode(geometry: geometry)
        let direction = forward()
        node.position = add(ship.position, multiply(direction, 2.7))
        scene.rootNode.addChildNode(node)
        shots.append(SpaceShot3D(node: node,
                                 velocity: add(shipVelocity, multiply(direction, 115)),
                                 remaining: CGFloat(rules.bulletLifetime)))
        if soundEnabled { ArcadeAudio.shared.play(.fire) }
    }

    /// A continuous-looking three-dimensional laser burst, with one
    /// instantaneous raycast per charge and a 0.3-second visible beam.
    private func fireBeam3D() {
        let lengthOfBeam: CGFloat = 145
        let origin = add(ship.position, multiply(forward(), 2.7))
        let heading = forward()
        let halo = SCNNode(geometry: SCNCylinder(radius: 0.22, height: lengthOfBeam))
        let core = SCNNode(geometry: SCNCylinder(radius: 0.07, height: lengthOfBeam))
        for (node, color) in [(halo, NSColor.systemCyan), (core, NSColor.white)] {
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = color
            material.emission.contents = color
            material.isDoubleSided = true
            node.geometry?.materials = [material]
            node.eulerAngles.x = .pi / 2
            node.position = SCNVector3(0, 0, -(2.7 + lengthOfBeam / 2))
            ship.addChildNode(node)
            node.runAction(.sequence([
                .wait(duration: Double(BeamBattery.beamSeconds)),
                .removeFromParentNode()
            ]))
        }
        if soundEnabled { ArcadeAudio.shared.play(.beam) }
        let countAtFire = rocks.count
        if countAtFire == 0 { return }
        for i in stride(from: countAtFire - 1, through: 0, by: -1) {
            let rockPosition = rocks[i].node.position
            let delta = subtract(rockPosition, origin)
            let along = dot(delta, heading)
            guard along >= 0 && along <= lengthOfBeam else { continue }
            let closest = add(origin, multiply(heading, along))
            guard length(subtract(rockPosition, closest)) <= radius(for: rocks[i].level) + 0.28 else {
                continue
            }
            if rocks[i].health > 1 {
                rocks[i].health -= 1
                rocks[i].fractureTime = min(
                    rocks[i].fractureTime ?? 10,
                    rocks[i].health <= 1 ? 5 : 10
                )
                rocks[i].node.geometry?.firstMaterial?.diffuse.contents = NSColor.orange
            } else {
                split(at: i, awardPoints: true)
            }
        }
    }

    private func forward() -> SCNVector3 {
        let cp = cos(pitch)
        return normalize(SCNVector3(-sin(yaw) * cp, sin(pitch), -cos(yaw) * cp))
    }

    private func right() -> SCNVector3 {
        normalize(SCNVector3(cos(yaw), 0, -sin(yaw)))
    }

    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let dt = previous == 0 ? CGFloat(1 / 60.0) : CGFloat(min(1 / 30.0, max(0, time - previous)))
        previous = time
        guard !paused && !gameOver else { return }
        elapsed += dt
        ammo.update(dt: dt, secondsSinceShot: elapsed - lastShot,
                    triggerHeld: pressed.contains(49) && (!shiftHeld || beamBattery.charges == 0))
        beamBattery.update(dt: dt)

        if pressed.contains(123) { yaw += dt * 1.45 }
        if pressed.contains(124) { yaw -= dt * 1.45 }
        if pressed.contains(34) { pitch += dt * 1.45 } // I pitch up
        if pressed.contains(40) { pitch -= dt * 1.45 } // K pitch down
        if pressed.contains(12) { roll += dt * 1.55 } // Q roll
        if pressed.contains(14) { roll -= dt * 1.55 } // E roll
        pitch = max(-1.35, min(1.35, pitch))
        ship.eulerAngles = SCNVector3(-pitch, yaw, roll)

        let direction = forward()
        if pressed.contains(126) {
            shipVelocity = add(shipVelocity, multiply(direction, 53 * dt))
        }
        if pressed.contains(125) {
            shipVelocity = subtract(shipVelocity, multiply(direction, 28 * dt))
        }
        if pressed.contains(0) { shipVelocity = subtract(shipVelocity, multiply(right(), 32 * dt)) } // A
        if pressed.contains(2) { shipVelocity = add(shipVelocity, multiply(right(), 32 * dt)) } // D
        if pressed.contains(13) { shipVelocity.y += 31 * dt } // W
        if pressed.contains(7) { shipVelocity.y -= 31 * dt } // X

        let maxSpeed: CGFloat = difficulty == "hard" ? 75 : 65
        let magnitude = length(shipVelocity)
        if magnitude > maxSpeed { shipVelocity = multiply(normalize(shipVelocity), maxSpeed) }
        ship.position = moveAtEdge(add(ship.position, multiply(shipVelocity, dt)),
                                    velocity: &shipVelocity)

        if pressed.contains(49) && shiftHeld && beamBattery.charges > 0 {
            if elapsed - lastBeamFire >= BeamBattery.fireInterval && beamBattery.fire() {
                lastBeamFire = elapsed
                fireBeam3D()
            }
        } else if pressed.contains(49) && elapsed - lastShot > CGFloat(rules.shotInterval)
            && shots.count < rules.maxBullets && ammo.fire() {
            lastShot = elapsed
            fire()
        }

        if shieldActive {
            shieldRemaining -= dt
            if shieldRemaining <= 0 { stopShield() }
        } else if shieldCooldownRemaining > 0 {
            shieldCooldownRemaining = max(0, shieldCooldownRemaining - dt)
        }

        updateBlackHole(dt)
        updateNuclearMissile(dt)
        for i in rocks.indices.reversed() {
            let next = add(rocks[i].node.position, multiply(rocks[i].velocity, dt))
            rocks[i].node.position = moveAtEdge(next, velocity: &rocks[i].velocity)
            rocks[i].node.eulerAngles.y += dt * 0.15
            if let remaining = rocks[i].fractureTime {
                if remaining <= dt {
                    split(at: i, awardPoints: false)
                } else {
                    rocks[i].fractureTime = remaining - dt
                }
            }
        }
        for i in shots.indices.reversed() {
            shots[i].remaining -= dt
            let next = add(shots[i].node.position, multiply(shots[i].velocity, dt))
            shots[i].node.position = moveAtEdge(next, velocity: &shots[i].velocity)
            if shots[i].remaining <= 0 {
                shots.remove(at: i).node.removeFromParentNode()
                continue
            }
            let point = shots[i].node.position
            if let rockIndex = rocks.firstIndex(where: {
                length(subtract($0.node.position, point)) < radius(for: $0.level) + 0.22
            }) {
                shots.remove(at: i).node.removeFromParentNode()
                if rocks[rockIndex].health > 1 {
                    rocks[rockIndex].health -= 1
                    rocks[rockIndex].fractureTime = min(
                        rocks[rockIndex].fractureTime ?? 10,
                        rocks[rockIndex].health <= 1 ? 5 : 10
                    )
                    rocks[rockIndex].node.geometry?.firstMaterial?.diffuse.contents = NSColor.orange
                } else {
                    split(at: rockIndex, awardPoints: true)
                }
            }
        }
        if !shieldActive && elapsed > invulnerableUntil &&
            rocks.contains(where: { length(subtract($0.node.position, ship.position)) < radius(for: $0.level) + 1.5 }) {
            lives -= 1
            invulnerableUntil = elapsed + (difficulty == "easy" ? 3 : 2)
            if soundEnabled { ArcadeAudio.shared.play(.ship) }
            if lives <= 0 {
                gameOver = true
                message = "GAME OVER — PRESS R"
            } else {
                ship.position = SCNVector3Zero
                shipVelocity = SCNVector3Zero
            }
        }
        if shieldActive {
            for i in rocks.indices {
                let gap = subtract(rocks[i].node.position, ship.position)
                let distance = length(gap)
                let target = radius(for: rocks[i].level) + 2.65
                if distance < target && distance > 0.01 {
                    let normal = normalize(gap)
                    rocks[i].node.position = add(ship.position, multiply(normal, target + 0.1))
                    let relative = subtract(rocks[i].velocity, shipVelocity)
                    let inbound = dot(relative, normal)
                    if inbound < 0 {
                        rocks[i].velocity = add(shipVelocity,
                            subtract(relative, multiply(normal, 2.15 * inbound)))
                    }
                }
            }
        }
        if rocks.isEmpty {
            wave += 1
            missilesRemaining = rules.missilesPerWave
            spawnWave()
        }
    }

    private func launchNuclearMissile() {
        guard missilesRemaining > 0 && nuclearMissile == nil && !gameOver else { return }
        missilesRemaining -= 1
        let body = SCNCapsule(capRadius: 0.34, height: 1.9)
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.orange
        material.emission.contents = NSColor(calibratedRed: 0.65, green: 0.30, blue: 0.08, alpha: 1)
        body.firstMaterial = material
        let node = SCNNode(geometry: body)
        let heading = forward()
        node.position = add(ship.position, multiply(heading, 5.2))
        node.eulerAngles = ship.eulerAngles
        scene.rootNode.addChildNode(node)
        nuclearMissile = NuclearMissile3D(node: node,
            velocity: add(multiply(shipVelocity, 0.65), multiply(heading, 90)),
            fuse: 2.5)
        if soundEnabled { ArcadeAudio.shared.play(.fire) }
    }

    private func updateNuclearMissile(_ dt: CGFloat) {
        guard var missile = nuclearMissile else { return }
        missile.fuse -= dt
        missile.node.position = moveAtEdge(add(missile.node.position,
                                             multiply(missile.velocity, dt)), velocity: &missile.velocity)
        missile.velocity = multiply(missile.velocity, max(0, 1 - dt * 0.12))
        if missile.fuse > 0 {
            nuclearMissile = missile
            return
        }
        nuclearMissile = nil
        missile.node.removeFromParentNode()
        let point = missile.node.position
        // A spherical blast approximately one third of the arena's span.
        let blastRadius: CGFloat = 48
        let sphere = SCNNode(geometry: SCNSphere(radius: 1))
        let effect = SCNMaterial()
        effect.diffuse.contents = NSColor(calibratedRed: 1, green: 0.48, blue: 0.12, alpha: 0.24)
        effect.emission.contents = NSColor.orange
        effect.transparency = 0.30
        effect.fillMode = .lines
        sphere.geometry?.materials = [effect]
        sphere.position = point
        scene.rootNode.addChildNode(sphere)
        sphere.runAction(.sequence([
            .group([.scale(to: CGFloat(blastRadius), duration: 0.65),
                    .fadeOut(duration: 0.65)]),
            .removeFromParentNode()
        ]))
        // Unsafe close-range detonations destroy the player even with shield
        // or temporary respawn protection. Do not double-apply a normal hit.
        if length(subtract(ship.position, point)) < 19 && !gameOver {
            lives -= 1
            invulnerableUntil = elapsed + 2
            if soundEnabled { ArcadeAudio.shared.play(.ship) }
            ship.position = SCNVector3Zero
            shipVelocity = SCNVector3Zero
            shieldActive = false
            shield.isHidden = true
            if lives <= 0 {
                gameOver = true
                message = "NUCLEAR BLAST — GAME OVER"
            }
        }
        for index in rocks.indices.reversed() {
            let rock = rocks[index]
            guard length(subtract(rock.node.position, point)) < blastRadius + radius(for: rock.level) else { continue }
            rock.node.removeFromParentNode()
            rocks.remove(at: index)
            score += 20 * (6 - rock.level)
        }
        if soundEnabled { ArcadeAudio.shared.play(.nuclear) }
    }

    private func saved(_ v: SCNVector3) -> SavedVector3D {
        SavedVector3D(x: Double(v.x), y: Double(v.y), z: Double(v.z))
    }
    private func loaded(_ v: SavedVector3D) -> SCNVector3 {
        SCNVector3(CGFloat(v.x), CGFloat(v.y), CGFloat(v.z))
    }

    func makeSnapshot() -> Flight3DSnapshot? {
        guard !gameOver && !paused else { return nil }
        return Flight3DSnapshot(
            difficulty: difficulty, customRules: customRules,
            score: score, lives: lives, wave: wave, elapsed: Double(elapsed),
            yaw: Double(yaw), pitch: Double(pitch), roll: Double(roll),
            shipPosition: saved(ship.position), shipVelocity: saved(shipVelocity),
            protectionRemaining: Double(max(0, invulnerableUntil - elapsed)),
            shieldActive: shieldActive, shieldRemaining: Double(shieldRemaining),
            shieldRechargeRemaining: Double(shieldCooldownRemaining),
            lastShotAgo: Double(elapsed - lastShot), ammoReserve: ammo,
            beamBattery: beamBattery, missilesRemaining: missilesRemaining,
            missile: nuclearMissile.map {
                SavedShot3D(position: saved($0.node.position),
                            velocity: saved($0.velocity), remaining: Double($0.fuse))
            },
            rocks: rocks.map {
                SavedRock3D(level: $0.level, position: saved($0.node.position),
                            velocity: saved($0.velocity), health: $0.health,
                            fractureRemaining: $0.fractureTime.map { Double($0) })
            },
            shots: shots.map {
                SavedShot3D(position: saved($0.node.position),
                            velocity: saved($0.velocity), remaining: Double($0.remaining))
            },
            blackHolePosition: blackHole.map { saved($0.position) },
            blackHoleRemaining: Double(blackHoleRemaining),
            lastBlackHoleAgo: Double(elapsed - lastBlackHole),
            nextBlackHoleDelay: Double(nextBlackHoleDelay))
    }

    func restore(_ data: Flight3DSnapshot) {
        difficulty = data.difficulty
        customRules = data.customRules
        restart()
        for rock in rocks { rock.node.removeFromParentNode() }
        for shot in shots { shot.node.removeFromParentNode() }
        rocks.removeAll()
        shots.removeAll()
        elapsed = CGFloat(data.elapsed)
        previous = 0
        score = data.score
        lives = data.lives
        wave = data.wave
        yaw = CGFloat(data.yaw)
        pitch = CGFloat(data.pitch)
        roll = CGFloat(data.roll)
        ship.eulerAngles = SCNVector3(-pitch, yaw, roll)
        ship.position = loaded(data.shipPosition)
        shipVelocity = loaded(data.shipVelocity)
        invulnerableUntil = elapsed + CGFloat(data.protectionRemaining)
        shieldActive = data.shieldActive
        shieldRemaining = CGFloat(data.shieldRemaining)
        shieldCooldownRemaining = CGFloat(data.shieldRechargeRemaining)
        shield.isHidden = !shieldActive
        lastShot = elapsed - CGFloat(data.lastShotAgo)
        ammo = data.ammoReserve ?? AmmoReserve()
        ammo.normalize()
        beamBattery = data.beamBattery ?? BeamBattery()
        beamBattery.normalize()
        lastBeamFire = elapsed - BeamBattery.fireInterval
        shiftHeld = false
        missilesRemaining = data.missilesRemaining
        lastBlackHole = elapsed - CGFloat(data.lastBlackHoleAgo)
        nextBlackHoleDelay = CGFloat(data.nextBlackHoleDelay)
        paused = false
        gameOver = false
        pressed.removeAll()
        for rock in data.rocks {
            addRock(level: rock.level, at: loaded(rock.position),
                    velocity: loaded(rock.velocity),
                    health: rock.health,
                    timer: rock.fractureRemaining.map { CGFloat($0) })
            if rock.health < rules.hits(level: rock.level, difficulty: difficulty) {
                rocks[rocks.count - 1].node.geometry?.firstMaterial?.diffuse.contents = NSColor.orange
            }
        }
        for savedShot in data.shots {
            let node = SCNNode(geometry: SCNSphere(radius: 0.22))
            node.geometry?.firstMaterial?.emission.contents = NSColor.cyan
            node.position = loaded(savedShot.position)
            scene.rootNode.addChildNode(node)
            shots.append(SpaceShot3D(node: node, velocity: loaded(savedShot.velocity),
                                     remaining: CGFloat(savedShot.remaining)))
        }
        if let savedMissile = data.missile {
            let node = SCNNode(geometry: SCNCapsule(capRadius: 0.34, height: 1.9))
            node.geometry?.firstMaterial?.emission.contents = NSColor.orange
            node.position = loaded(savedMissile.position)
            scene.rootNode.addChildNode(node)
            nuclearMissile = NuclearMissile3D(node: node,
                velocity: loaded(savedMissile.velocity), fuse: CGFloat(savedMissile.remaining))
        }
        blackHole?.removeFromParentNode()
        blackHole = nil
        if let position = data.blackHolePosition {
            spawnBlackHole()
            blackHole?.position = loaded(position)
            blackHoleRemaining = CGFloat(data.blackHoleRemaining)
        }
    }

    private func radius(for level: Int) -> CGFloat {
        [0, 0.9, 1.65, 2.8, 4.4, 6.3][min(5, max(1, level))]
    }

    private func split(at index: Int, awardPoints: Bool) {
        let rock = rocks.remove(at: index)
        rock.node.removeFromParentNode()
        if soundEnabled { ArcadeAudio.shared.playRockBreak(level: rock.level) }
        if awardPoints { score += 20 * (6 - rock.level) }
        guard rock.level > 1 else { return }
        for side in [-1.0, 1.0] as [CGFloat] {
            let offset = SCNVector3(side * 2, side * 1.5, -side)
            let nextDirection = normalize(add(rock.velocity, multiply(offset, 25)))
            addRock(level: rock.level - 1, at: rock.node.position,
                    velocity: multiply(nextDirection, speed(for: rock.level - 1)))
        }
    }

    private func moveAtEdge(_ p: SCNVector3,
                            velocity: inout SCNVector3) -> SCNVector3 {
        guard rules.edgeMode == .bounce else { return wrapped(p) }
        var position = p
        if position.x < -boundary { position.x = -boundary; velocity.x = abs(velocity.x) }
        if position.x > boundary { position.x = boundary; velocity.x = -abs(velocity.x) }
        if position.y < -boundary { position.y = -boundary; velocity.y = abs(velocity.y) }
        if position.y > boundary { position.y = boundary; velocity.y = -abs(velocity.y) }
        if position.z < -boundary { position.z = -boundary; velocity.z = abs(velocity.z) }
        if position.z > boundary { position.z = boundary; velocity.z = -abs(velocity.z) }
        return position
    }

    private func spawnBlackHole() {
        let hole = BlackHoleArtwork.flight3D()
        hole.position = SCNVector3(CGFloat.random(in: -58...58),
                                   CGFloat.random(in: -48...48),
                                   CGFloat.random(in: -82...(-20)))
        scene.rootNode.addChildNode(hole)
        blackHole = hole
        blackHoleRemaining = 13
        if soundEnabled { ArcadeAudio.shared.play(.comet) }
    }

    private func updateBlackHole(_ dt: CGFloat) {
        guard rules.blackHoleEnabled else {
            blackHole?.removeFromParentNode()
            blackHole = nil
            return
        }
        if blackHole == nil && wave >= 3 && elapsed - lastBlackHole > nextBlackHoleDelay {
            spawnBlackHole()
        }
        guard let hole = blackHole else { return }
        blackHoleRemaining -= dt
        if blackHoleRemaining <= 0 {
            hole.removeFromParentNode()
            blackHole = nil
            lastBlackHole = elapsed
            nextBlackHoleDelay = CGFloat.random(in: 30...46)
            return
        }
        hole.eulerAngles.y += dt * 0.4
        let center = hole.position
        func gravity(_ position: SCNVector3) -> SCNVector3 {
            let delta = subtract(center, position)
            let distance = max(0.1, length(delta))
            guard distance < 115 else { return SCNVector3Zero }
            let strength = min(CGFloat(140), 3400 / max(20, distance))
            return multiply(normalize(delta), strength * dt)
        }
        shipVelocity = add(shipVelocity, gravity(ship.position))
        if length(subtract(ship.position, center)) < 5.0 && elapsed > invulnerableUntil {
            lives -= 1
            if soundEnabled { ArcadeAudio.shared.play(.ship) }
            ship.position = SCNVector3Zero
            shipVelocity = SCNVector3Zero
            invulnerableUntil = elapsed + 2
            if lives <= 0 {
                gameOver = true
                message = "BLACK HOLE — GAME OVER"
            }
        }
        for i in rocks.indices.reversed() {
            rocks[i].velocity = add(rocks[i].velocity, gravity(rocks[i].node.position))
            if length(subtract(rocks[i].node.position, center)) < 5.5 {
                rocks.remove(at: i).node.removeFromParentNode()
            }
        }
        for i in shots.indices.reversed() {
            shots[i].velocity = add(shots[i].velocity, gravity(shots[i].node.position))
            if length(subtract(shots[i].node.position, center)) < 5.0 {
                shots.remove(at: i).node.removeFromParentNode()
            }
        }
        if var missile = nuclearMissile {
            missile.velocity = add(missile.velocity, gravity(missile.node.position))
            nuclearMissile = missile
        }
    }

    private func wrapped(_ p: SCNVector3) -> SCNVector3 {
        guard rules.edgeMode == .wrap else {
            return SCNVector3(max(-boundary, min(boundary, p.x)),
                              max(-boundary, min(boundary, p.y)),
                              max(-boundary, min(boundary, p.z)))
        }
        func wrappedCoordinate(_ number: CGFloat) -> CGFloat {
            if number > boundary { return -boundary }
            if number < -boundary { return boundary }
            return number
        }
        return SCNVector3(wrappedCoordinate(p.x), wrappedCoordinate(p.y), wrappedCoordinate(p.z))
    }

    private func add(_ a: SCNVector3, _ b: SCNVector3) -> SCNVector3 {
        SCNVector3(a.x + b.x, a.y + b.y, a.z + b.z)
    }
    private func subtract(_ a: SCNVector3, _ b: SCNVector3) -> SCNVector3 {
        SCNVector3(a.x - b.x, a.y - b.y, a.z - b.z)
    }
    private func multiply(_ vector: SCNVector3, _ amount: CGFloat) -> SCNVector3 {
        SCNVector3(vector.x * amount, vector.y * amount, vector.z * amount)
    }
    private func dot(_ a: SCNVector3, _ b: SCNVector3) -> CGFloat {
        a.x * b.x + a.y * b.y + a.z * b.z
    }
    private func length(_ v: SCNVector3) -> CGFloat {
        sqrt(dot(v, v))
    }
    private func normalize(_ v: SCNVector3) -> SCNVector3 {
        let amount = max(0.0001, length(v))
        return multiply(v, 1 / amount)
    }
}
