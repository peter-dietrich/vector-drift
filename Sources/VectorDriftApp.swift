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
    case classic, modern, flight3D
    var id: String { rawValue }
    var title: String {
        switch self {
        case .classic: return "Classic"
        case .modern: return "Modern"
        case .flight3D: return "3D Flight"
        }
    }
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
        // Every difficulty has a multi-hit upper tier so the unstable
        // fracture timer is meaningful in Easy, Medium, and Hard.
        switch self {
        case .easy: return level == 3 ? 2 : 1
        case .medium: return level == 4 ? 2 : 1
        case .hard: return level == 5 ? 3 : level == 4 ? 2 : 1
        }
    }

    var shieldCooldown: CGFloat {
        switch self {
        case .easy: return 5
        case .medium: return 7
        case .hard: return 9
        }
    }
}

private struct GameWindow: View {
    @AppStorage("visualMode") private var mode = Look.classic.rawValue
    @AppStorage("difficulty") private var difficulty = Difficulty.medium.rawValue
    @AppStorage("soundEnabled") private var soundEnabled = true
    @State private var showScores = false
    @State private var showPreferences = false
    @State private var showSavedGames = false
    @State private var activePresetID = ""
    @State private var savedGames: [GameSaveSlot] = []
    @State private var saved3DGames: [Flight3DSaveSlot] = []
    @State private var flight = Flight3DGame()
    @State private var game: DriftScene = {
        let scene = DriftScene(size: CGSize(width: 1080, height: 670))
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            Text("VECTOR DRIFT")
                                .font(.system(size: 19, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                            Text("v2026.11.12g")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.gray)
                                .help("Source build identifier: v2026.11.12g")
                        }
                        Text("ARCADE  /  MACOS   •   ISS TEST BUILD 2026.11.12b")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.cyan.opacity(0.7))
                    }
                    Spacer()
                    Button("ISS Test") {
                        if mode != Look.flight3D.rawValue {
                            game.spawnTestStation()
                        }
                    }
                    .help("Bring an ISS-style station into view to test bullet impacts")
                    Button("Custom Game") { showPreferences = true }
                    Button("Save Game") {
                        if mode == Look.flight3D.rawValue {
                            if let snapshot = flight.makeSnapshot() {
                                Flight3DStore.save(snapshot)
                            }
                        } else if let snapshot = game.makeSnapshot(activePresetID: activePresetID) {
                            _ = GameStore.saveGame(snapshot)
                        }
                    }
                    Button("Resume") {
                        savedGames = GameStore.saves()
                        saved3DGames = Flight3DStore.saves()
                        showSavedGames = true
                    }
                    Toggle("Sound", isOn: $soundEnabled)
                        .toggleStyle(.checkbox)
                    Button("Scores") { showScores = true }
                    Button("New Game") {
                        if mode == Look.flight3D.rawValue { flight.restart() }
                        else { game.restart() }
                    }
                        .keyboardShortcut("r", modifiers: [.command])
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                }
                HStack(spacing: 12) {
                    Text("DIFFICULTY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.gray)
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
                    Spacer()
                    Text("GRAPHICS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.gray)
                    HStack(spacing: 3) {
                    ForEach(Look.allCases) { look in
                        Button(look.title) { mode = look.rawValue }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(mode == look.rawValue ? Color.black : Color.white)
                            .frame(width: look == .classic ? 66 : 90, height: 28)
                            .background(mode == look.rawValue
                                        ? Color.cyan : Color(white: 0.28))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.white.opacity(0.38), lineWidth: 1))
                    }
                }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(white: 0.09))
            Group {
                if mode == Look.flight3D.rawValue {
                    Flight3DView(game: flight)
                } else {
                    GameView(scene: game, graphics: mode, selectedDifficulty: difficulty)
                }
            }
            .background(.black)
            HStack {
                Text(mode == Look.flight3D.rawValue
                    ? "3D: ← → Yaw  I K Pitch  Q E Roll  W X Rise/Dive  A D Strafe  ↑ Thrust  ↓ Reverse  Space Fire  ⇧+Space Laser  S Shield  N Missile"
                    : "← → Rotate  ↑ Thrust  Space Fire  ⇧+Space Laser  S Shield  N Missile  ↓ Warp  P Pause  R Restart")
                Spacer()
                if mode == Look.modern.rawValue {
                    Text("Sky: Original procedural vector nebula")
                        .foregroundStyle(.white.opacity(0.46))
                        .help("All space clouds and star clusters are generated locally. No photographic images are used.")
                } else {
                    Text("Click playfield for keyboard focus")
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .padding(12)
            .background(Color(white: 0.10))
        }
        .foregroundStyle(.white)
        .onAppear {
            game.modern = mode == Look.modern.rawValue
            game.difficulty = Difficulty(rawValue: difficulty) ?? .medium
            flight.difficulty = difficulty
            flight.soundEnabled = soundEnabled
            ArcadeAudio.shared.enabled = soundEnabled
        }
        .onChange(of: soundEnabled) {
            ArcadeAudio.shared.enabled = $0
            flight.soundEnabled = $0
        }
        .sheet(isPresented: $showPreferences) {
            GamePresetEditor(baseDifficulty: difficulty, activePresetID: activePresetID) { preset in
                activePresetID = preset?.id ?? ""
                game.customRules = preset?.rules
                flight.customRules = preset?.rules
                game.restart()
            }
        }
        .sheet(isPresented: $showSavedGames) {
            VStack(alignment: .leading, spacing: 12) {
                Text("SAVED GAMES").font(.title2.monospaced().bold())
                if savedGames.isEmpty && saved3DGames.isEmpty {
                    Text("No saved games yet. Start playing, then choose Save Game.")
                        .foregroundStyle(.secondary)
                }
                ScrollView {
                    ForEach(saved3DGames) { slot in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(slot.summary).font(.headline)
                                Text(slot.date.formatted()).font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Resume") {
                                mode = Look.flight3D.rawValue
                                difficulty = slot.snapshot.difficulty
                                activePresetID = ""
                                let snapshot = slot.snapshot
                                DispatchQueue.main.async { flight.restore(snapshot) }
                                showSavedGames = false
                            }
                            Button("Delete", role: .destructive) {
                                Flight3DStore.delete(id: slot.id)
                                saved3DGames = Flight3DStore.saves()
                            }
                        }
                        Divider()
                    }
                    ForEach(savedGames) { slot in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(slot.name).font(.headline)
                                Text(slot.savedAt.formatted()).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Resume") {
                                let snapshot = slot.snapshot
                                mode = snapshot.modern ? Look.modern.rawValue : Look.classic.rawValue
                                difficulty = snapshot.difficulty
                                activePresetID = snapshot.activePresetID
                                // Allow SwiftUI's difficulty change handler to finish first.
                                DispatchQueue.main.async { game.restore(snapshot) }
                                showSavedGames = false
                            }
                            Button("Delete", role: .destructive) {
                                GameStore.deleteGame(id: slot.id)
                                savedGames = GameStore.saves()
                            }
                        }
                        Divider()
                    }
                }
                Button("Close") { showSavedGames = false }
            }
            .padding(24).frame(width: 550, height: 450)
        }
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
        .onChange(of: mode) { value in
            game.modern = value == Look.modern.rawValue
            if value == Look.flight3D.rawValue { game.clearKeys() }
        }
        .onChange(of: difficulty) { value in
            game.difficulty = Difficulty(rawValue: value) ?? .medium
            flight.difficulty = value
            activePresetID = ""
            game.customRules = nil
            flight.customRules = nil
            game.refreshDifficultySelection()
        }
    }
}

private struct GameView: NSViewRepresentable {
    let scene: DriftScene
    let graphics: String
    let selectedDifficulty: String

    // Configure BEFORE presenting the scene. This is essential on a cold
    // launch, because @AppStorage's selected mode may already be Modern,
    // so SwiftUI won't call the onChange handler at all.
    func makeNSView(context: Context) -> KeyboardView {
        let view = KeyboardView()
        view.preferredFramesPerSecond = 60
        scene.modern = graphics == Look.modern.rawValue
        scene.difficulty = Difficulty(rawValue: selectedDifficulty) ?? .medium
        view.presentScene(scene)
        return view
    }

    // Keep the actual renderer synchronized with the mode buttons after
    // reattachments and when returning from the 3D SceneKit view.
    func updateNSView(_ view: KeyboardView, context: Context) {
        scene.modern = graphics == Look.modern.rawValue
        scene.difficulty = Difficulty(rawValue: selectedDifficulty) ?? .medium
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
    override func flagsChanged(with event: NSEvent) {
        (scene as? DriftScene)?.setShiftActive(event.modifierFlags.contains(.shift))
        super.flagsChanged(with: event)
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
    var surface: SKSpriteNode
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
    var decloakRemaining: CGFloat = 0
}

/// Orbital flybys: satellites are destructible; station structures take limited cosmetic damage.
private struct OrbitalTraffic {
    var node: SKNode
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
    var maxRadius: CGFloat
}
private struct NuclearMissile {
    var node: SKNode
    var velocity: CGVector
    var fuse: CGFloat
}
private struct BlackHoleEvent {
    var node: SKNode
    var remaining: CGFloat
}

final class DriftScene: SKScene {
    var modern = false {
        didSet {
            if modern != oldValue { updateStyle() }
        }
    }
    fileprivate var difficulty: Difficulty = .medium
    var customRules: GameRules?
    private var boulders: [Boulder] = []
    private var lasers: [Laser] = []
    private var beamBattery = BeamBattery()
    private var lastBeamFire: CGFloat = -2
    private var shiftHeld = false
    private var comet: Comet?
    private var shockwaves: [Shockwave] = []
    private var nuclearMissile: NuclearMissile?
    private var missilesRemaining = 2
    private var blackHole: BlackHoleEvent?
    private var lastBlackHole: CGFloat = 0
    private var nextBlackHoleDelay: CGFloat = 26
    private var lastComet: CGFloat = 0
    private var nextCometDelay: CGFloat = 13
    private var nextSpark: CGFloat = 0
    private var saucer: Saucer?
    private var satellite: OrbitalTraffic?
    private var station: OrbitalTraffic?
    private var stationDamage = 0
    private var nextSatelliteAt: CGFloat = 20
    private var nextStationAt: CGFloat = 36
    private var enemyShots: [EnemyShot] = []
    private var lastSaucer: CGFloat = 0
    private var nextSaucerDelay: CGFloat = 20
    private var lastSaucerShot: CGFloat = 0
    private var titleVisible = true
    private var scoreRecorded = false
    private var shieldActive = false
    private var shieldEnergy: CGFloat = 0
    private var shieldRechargeRemaining: CGFloat = 0
    private let shieldNode = ArcadeEffects.shield()
    // A guaranteed opaque floor for the entire scene, independent of
    // SwiftUI view timing, scene clear colors or procedural textures.
    private let spaceBackdrop = SKSpriteNode(color: .black, size: .zero)
    private let feedbackCamera = SKCameraNode()
    private var lastImpactShake: CGFloat = -2
    private var backgroundLayer: VectorNebulaField?
    // Cold launch needs several live SpriteKit frames before generating the
    // initial GPU textures. Gameplay regeneration already occurs after this.
    private var presentationFrames = 0
    private var lastBeltSpawn: CGFloat = 0
    private let modernShipDetail = ModernVisuals.shipDetail()
    private let flame = ModernVisuals.engineFlame()
    private var held = Set<UInt16>()
    private var lastTime: TimeInterval = 0
    private var elapsed: CGFloat = 0
    private var lastFire: CGFloat = -2
    private var ammo = AmmoReserve()
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
    private let statusHUD = SKLabelNode(fontNamed: "Menlo-Bold")
    private let message = SKLabelNode(fontNamed: "Menlo-Bold")
    private let classicTitleStars = SKNode()
    private let leftPanel = SKShapeNode(rectOf: CGSize(width: 304, height: 76), cornerRadius: 7)
    private let rightPanel = SKShapeNode(rectOf: CGSize(width: 304, height: 76), cornerRadius: 7)
    private let leftAccent = SKShapeNode(rectOf: CGSize(width: 2, height: 56))
    private let rightAccent = SKShapeNode(rectOf: CGSize(width: 2, height: 56))
    private let leftHeading = SKLabelNode(fontNamed: "Menlo-Bold")
    private let rightHeading = SKLabelNode(fontNamed: "Menlo-Bold")
    private let leftFootnote = SKLabelNode(fontNamed: "Menlo")
    private let rightFootnote = SKLabelNode(fontNamed: "Menlo")
    private let scoreCaption = SKLabelNode(fontNamed: "Menlo")
    private let waveCaption = SKLabelNode(fontNamed: "Menlo")
    private let waveValue = SKLabelNode(fontNamed: "Menlo-Bold")
    private let beltCaption = SKLabelNode(fontNamed: "Menlo")
    private let beltValue = SKLabelNode(fontNamed: "Menlo-Bold")
    private let difficultyReadout = SKLabelNode(fontNamed: "Menlo")
    private let ammoReadout = SKLabelNode(fontNamed: "Menlo-Bold")
    private let ammoStatus = SKLabelNode(fontNamed: "Menlo")
    private let beamStatus = SKLabelNode(fontNamed: "Menlo-Bold")
    private let telemetryRuleOne = SKShapeNode(rectOf: CGSize(width: 210, height: 0.7))
    private let telemetryRuleTwo = SKShapeNode(rectOf: CGSize(width: 210, height: 0.7))
    private let stageHeading = SKLabelNode(fontNamed: "Menlo-Bold")
    private let stageCaption = SKLabelNode(fontNamed: "Menlo")
    private let stagePanel = SKShapeNode(rectOf: CGSize(width: 398, height: 108), cornerRadius: 8)

    override func didMove(to view: SKView) {
        if ready {
            // The scene may be reattached to a new NSView. Its prepared
            // nebula survives; don't rebuild it in didMove().
            presentationFrames = 0
            didChangeSize(size)
            updateStyle()
            return
        }
        ready = true
        backgroundColor = .black
        feedbackCamera.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(feedbackCamera)
        camera = feedbackCamera
        spaceBackdrop.zPosition = -1000
        spaceBackdrop.color = .black
        spaceBackdrop.size = size
        spaceBackdrop.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(spaceBackdrop)
        ship.fillColor = .clear
        ship.lineWidth = 2
        ship.zPosition = 5
        addChild(ship)
        ship.addChild(modernShipDetail)
        ship.addChild(flame)
        ship.addChild(shieldNode)
        // A single right-side telemetry column, inspired by scientific
        // simulation readouts rather than two horizontal score banners.
        leftPanel.isHidden = true
        leftAccent.isHidden = true
        rightPanel.zPosition = 85
        rightPanel.fillColor = SKColor(calibratedRed: 0.035, green: 0.085, blue: 0.13, alpha: 0.13)
        rightPanel.strokeColor = SKColor(calibratedWhite: 0.81, alpha: 0.17)
        rightPanel.lineWidth = 0.55
        addChild(rightPanel)
        rightAccent.zPosition = 87
        rightAccent.strokeColor = .clear
        rightAccent.fillColor = SKColor(calibratedRed: 1, green: 0.65, blue: 0.29, alpha: 0.61)
        addChild(rightAccent)
        for rule in [telemetryRuleOne, telemetryRuleTwo] {
            rule.zPosition = 88
            rule.fillColor = SKColor(calibratedWhite: 0.81, alpha: 0.18)
            rule.strokeColor = .clear
            addChild(rule)
        }
        let telemetryLabels = [
            leftHeading, scoreCaption, hud, leftFootnote,
            waveCaption, waveValue, beltCaption, beltValue,
            rightHeading, statusHUD, rightFootnote, difficultyReadout,
            ammoReadout, ammoStatus, beamStatus
        ]
        for label in telemetryLabels {
            label.zPosition = 90
            label.horizontalAlignmentMode = .right
            label.verticalAlignmentMode = .top
            addChild(label)
        }
        for label in [stageHeading, stageCaption] {
            label.zPosition = 90
            addChild(label)
        }
        let amber = SKColor(calibratedRed: 1.0, green: 0.72, blue: 0.40, alpha: 0.92)
        let muted = SKColor(calibratedWhite: 0.79, alpha: 0.94)
        for label in [leftHeading, rightHeading] {
            label.fontSize = 9
            label.fontColor = amber
        }
        for label in [scoreCaption, waveCaption, beltCaption] {
            label.fontSize = 9
            label.fontColor = muted
        }
        leftHeading.text = "VECTOR DRIFT  //  TELEMETRY"
        scoreCaption.text = "CURRENT SCORE"
        waveCaption.text = "CURRENT WAVE"
        beltCaption.text = "BELT DENSITY"
        rightHeading.text = "COMBAT SYSTEMS"
        stageHeading.text = "VECTOR DRIFT   //   FLIGHT SIM"
        hud.fontSize = 30
        leftFootnote.fontSize = 11
        waveValue.fontSize = 29
        beltValue.fontSize = 24
        statusHUD.fontSize = 15
        rightFootnote.fontSize = 11
        difficultyReadout.fontSize = 10
        ammoReadout.fontSize = 14
        ammoStatus.fontSize = 9
        beamStatus.fontSize = 9
        for label in [leftFootnote, rightFootnote, difficultyReadout, ammoStatus] {
            label.fontColor = muted
        }
        stageHeading.fontSize = 8.5
        stageHeading.fontColor = amber
        stageCaption.fontSize = 10
        stageCaption.fontColor = SKColor(calibratedWhite: 0.85, alpha: 1)
        stagePanel.zPosition = 80
        stagePanel.fillColor = SKColor(calibratedRed: 0.035, green: 0.085, blue: 0.13, alpha: 0.22)
        stagePanel.strokeColor = ModernVisuals.ice.withAlphaComponent(0.23)
        stagePanel.lineWidth = 0.7
        stagePanel.isHidden = true
        addChild(stagePanel)
        classicTitleStars.zPosition = -28
        addChild(classicTitleStars)
        for i in 0..<130 {
            let r: CGFloat = i.isMultiple(of: 12) ? 1.25 : CGFloat.random(in: 0.25...0.75)
            let star = SKShapeNode(circleOfRadius: r)
            star.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                    y: CGFloat.random(in: 0...size.height))
            star.fillColor = .white.withAlphaComponent(CGFloat.random(in: 0.18...0.68))
            star.strokeColor = .clear
            classicTitleStars.addChild(star)
        }
        classicTitleStars.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.52, duration: 3.2),
            .fadeAlpha(to: 1.0, duration: 3.2)
        ])))
        message.zPosition = 91
        message.fontSize = 35
        message.horizontalAlignmentMode = .center
        addChild(message)
        // All telemetry labels use the same right-aligned baseline.
        leftHeading.horizontalAlignmentMode = .right
        leftFootnote.horizontalAlignmentMode = .right
        rightHeading.horizontalAlignmentMode = .right
        rightFootnote.horizontalAlignmentMode = .right
        stageHeading.horizontalAlignmentMode = .center
        stageCaption.horizontalAlignmentMode = .center
        showTitle()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        feedbackCamera.removeAction(forKey: "impactShake")
        feedbackCamera.position = CGPoint(x: size.width / 2, y: size.height / 2)
        spaceBackdrop.size = size
        spaceBackdrop.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backgroundLayer?.resize(to: size)
        // 15% smaller than the preceding right column; extra ammunition
        // readouts fit by tightening vertical spacing, not enlarging the glass.
        let inset: CGFloat = 14
        let columnWidth: CGFloat = min(214, max(178, size.width * 0.20))
        let layoutScale: CGFloat = min(0.85, max(0.61, (size.height - 30) / 480))
        let columnHeight: CGFloat = 412 * layoutScale
        let topY = size.height - 15
        let leftX = size.width - inset - columnWidth
        let textX = size.width - inset - 13
        rightPanel.path = CGPath(roundedRect: CGRect(
            x: -columnWidth / 2, y: -columnHeight / 2,
            width: columnWidth, height: columnHeight),
            cornerWidth: 7, cornerHeight: 7, transform: nil)
        rightPanel.position = CGPoint(x: leftX + columnWidth / 2,
                                      y: topY - columnHeight / 2)
        rightAccent.path = CGPath(rect: CGRect(
            x: -1, y: -(columnHeight - 21) / 2,
            width: 2, height: columnHeight - 21), transform: nil)
        rightAccent.position = CGPoint(x: leftX + 5,
                                       y: topY - columnHeight / 2)

        func put(_ label: SKLabelNode, _ offset: CGFloat) {
            label.position = CGPoint(x: textX, y: topY - offset * layoutScale)
            label.setScale(layoutScale)
        }
        put(leftHeading, 16)
        put(scoreCaption, 47)
        put(hud, 61)
        put(leftFootnote, 101)
        put(waveCaption, 136)
        put(waveValue, 148)
        put(beltCaption, 200)
        put(beltValue, 214)
        put(rightHeading, 269)
        put(statusHUD, 285)
        put(rightFootnote, 316)
        put(difficultyReadout, 341)
        put(ammoReadout, 356)
        put(ammoStatus, 374)
        put(beamStatus, 395)
        for (rule, offset) in [(telemetryRuleOne, CGFloat(119)),
                               (telemetryRuleTwo, CGFloat(249))] {
            rule.path = CGPath(rect: CGRect(
                x: 0, y: 0, width: columnWidth - 27, height: 0.6), transform: nil)
            rule.position = CGPoint(x: leftX + 14, y: topY - offset * layoutScale)
        }
        message.position = CGPoint(x: size.width / 2, y: size.height / 2 + 1)
        stageHeading.position = CGPoint(x: size.width / 2,
            y: size.height / 2 + (titleVisible ? -6 : 31))
        stageCaption.position = CGPoint(x: size.width / 2,
            y: size.height / 2 + (titleVisible ? -42 : -31))
        stagePanel.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    func restart() {
        feedbackCamera.removeAction(forKey: "impactShake")
        feedbackCamera.position = CGPoint(x: size.width / 2, y: size.height / 2)
        lastImpactShake = -2
        ArcadeAudio.shared.stopThrust()
        guard ready else { return }
        boulders.forEach { $0.node.removeFromParent() }
        lasers.forEach { $0.node.removeFromParent() }
        clearSpecialEffects()
        blackHole?.node.removeFromParent()
        blackHole = nil
        nuclearMissile?.node.removeFromParent()
        nuclearMissile = nil
        clearEnemies()
        clearOrbitalTraffic()
        boulders.removeAll()
        lasers.removeAll()
        held.removeAll()
        score = 0; lives = customRules?.startingLives ?? difficulty.startingLives; wave = 1
        elapsed = 0; lastTime = 0; lastFire = -2; lastWarp = -10
        ammo = AmmoReserve()
        beamBattery = BeamBattery()
        lastBeamFire = -2
        shiftHeld = false
        stopped = false; over = false
        titleVisible = false
        scoreRecorded = false
        shieldActive = false
        shieldEnergy = CGFloat(customRules?.shieldDuration ?? Double(difficulty.shieldDuration))
        shieldRechargeRemaining = 0
        missilesRemaining = customRules?.missilesPerWave ?? 2
        lastComet = 0
        lastBlackHole = 0
        nextBlackHoleDelay = CGFloat.random(in: 24...36)
        nextCometDelay = CGFloat.random(in: difficulty.cometDelay)
        lastSaucer = 0
        nextSaucerDelay = CGFloat.random(in: difficulty.saucerDelay)
        nextSatelliteAt = 20
        nextStationAt = 36
        lastSaucerShot = 0
        nextSpark = 0
        lastBeltSpawn = 0
        resetShip()
        protectedUntil = difficulty.respawnProtection
        ship.removeAllActions()
        ship.alpha = 1
        ship.setScale(1)
        ship.isHidden = false
        classicTitleStars.isHidden = true
        shieldNode.isHidden = true
        message.text = ""
        stageHeading.fontSize = 8.5
        stageHeading.fontColor = SKColor(calibratedRed: 1, green: 0.72, blue: 0.4, alpha: 0.92)
        stageCaption.fontSize = 10
        stageCaption.fontColor = SKColor(calibratedWhite: 0.85, alpha: 1)
        stagePanel.isHidden = true
        stageHeading.isHidden = true
        stageCaption.isHidden = true
        ArcadeAudio.shared.play(.wave)
        spawnWave()
        updateHud()
        if modern {
            // A new game gets new space artwork, but mode toggles never
            // discard all of the textures and shaders.
            if backgroundLayer == nil {
                updateStyle()
            } else {
                backgroundLayer?.regenerate()
            }
        } else {
            updateStyle()
        }
    }

    private func resetShip() {
        ship.position = CGPoint(x: size.width / 2, y: size.height / 2)
        ship.zRotation = 0
        heading = 0
        velocity = .zero
    }

    func clearKeys() {
        held.removeAll()
        shiftHeld = false
        ArcadeAudio.shared.stopThrust()
    }

    func setShiftActive(_ active: Bool) {
        shiftHeld = active
    }

    private func showTitle() {
        ArcadeAudio.shared.stopThrust()
        titleVisible = true
        stopped = false
        over = false
        // Hide the ship at (0, 0) and any residual gameplay objects until
        // the user starts. They will be restored by restart().
        ship.isHidden = true
        for rock in boulders { rock.node.isHidden = true }
        lives = customRules?.startingLives ?? difficulty.startingLives
        message.text = ""
        stageHeading.removeAllActions()
        stageHeading.text = "PRESS RETURN TO BEGIN"
        stageHeading.fontSize = 23
        stageHeading.fontColor = .white
        stageCaption.text = "FUN CITY  //  ORIGINAL ARCADE FLIGHT"
        stageCaption.fontSize = 12
        stageCaption.fontColor = SKColor(calibratedWhite: 0.86, alpha: 0.94)
        stagePanel.isHidden = true
        classicTitleStars.isHidden = !modern && !titleVisible
        stageHeading.position = CGPoint(x: size.width / 2, y: size.height / 2 - 6)
        stageCaption.position = CGPoint(x: size.width / 2, y: size.height / 2 - 42)
        stageHeading.isHidden = false
        stageCaption.isHidden = false
        message.position = CGPoint(x: size.width / 2, y: size.height / 2 + 1)
        updateStyle()
    }

    // A difficulty selection on the title screen should not silently start
    // the game. While playing, preserve the existing restart behavior.
    func refreshDifficultySelection() {
        guard ready else { return }
        if titleVisible {
            lives = customRules?.startingLives ?? difficulty.startingLives
            updateHud()
        } else {
            restart()
        }
    }

    func key(_ code: UInt16, down: Bool, isRepeat: Bool) {
        if down { held.insert(code) } else { held.remove(code) }
        guard down && !isRepeat else { return }
        if titleVisible || over {
            if code == 36 || code == 49 || code == 15 { restart() }
            return
        }
        switch code {
        case 1: // S toggles an unlimited number of timed shield charges.
            guard !stopped else { break }
            if shieldActive {
                startShieldRecharge()
            } else if shieldRechargeRemaining <= 0 {
                shieldActive = true
                shieldEnergy = CGFloat(customRules?.shieldDuration ?? Double(difficulty.shieldDuration))
                shieldNode.isHidden = false
                ArcadeAudio.shared.play(.shield)
            }
        case 45: // N: launch a drifting high-yield missile.
            if !stopped { launchNuclearMissile() }
        case 35: // P
            if !over {
                stopped.toggle()
                if stopped { ArcadeAudio.shared.stopThrust() }
                message.text = stopped ? "PAUSED" : ""
                stagePanel.isHidden = !stopped
                stageHeading.isHidden = !stopped
                stageCaption.isHidden = !stopped
                if stopped {
                    stageHeading.text = "FLIGHT CONTROL    //    HOLD"
                    stageCaption.text = "PRESS P TO RESUME"
                }
            }
        case 15: restart() // R
        case 125: if !stopped && !over { hyperspace() }
        default: break
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? CGFloat(1.0 / 60) : CGFloat(min(max(currentTime - lastTime, 0), 1.0 / 30))
        lastTime = currentTime
        guard ready else { return }
        // Scene initialization runs before the renderer is ready on some Macs.
        // The first launch used to create invalid/white nebula textures that
        // were only repaired by pressing Return (which regenerated the sky).
        // Prepare them after three actual update frames, not in didMove.
        presentationFrames += 1
        if modern && presentationFrames >= 3 {
            backgroundLayer?.prepareIfNeeded()
        }
        if titleVisible {
            elapsed += dt
            if modern {
                backgroundLayer?.animate(time: elapsed, density: 0.45,
                                         shipVelocity: .zero, thrusting: false)
            }
            return
        }
        guard !over && !stopped else {
            ArcadeAudio.shared.stopThrust()
            return
        }
        elapsed += dt
        if shieldActive {
            shieldEnergy = max(0, shieldEnergy - dt)
            if shieldEnergy <= 0 {
                startShieldRecharge()
            }
        } else if shieldRechargeRemaining > 0 {
            shieldRechargeRemaining = max(0, shieldRechargeRemaining - dt)
            if shieldRechargeRemaining == 0 {
                shieldEnergy = CGFloat(customRules?.shieldDuration ?? Double(difficulty.shieldDuration))
            }
        }
        ArcadeEffects.updateShield(shieldNode, modern: modern,
                                   remaining: shieldActive ? shieldEnergy : 0,
                                   total: difficulty.shieldDuration)
        ammo.update(dt: dt, secondsSinceShot: elapsed - lastFire,
                    triggerHeld: held.contains(49) && (!shiftHeld || beamBattery.charges == 0))
        beamBattery.update(dt: dt)
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
        let nextShipPosition = CGPoint(x: ship.position.x + velocity.dx * dt,
                                       y: ship.position.y + velocity.dy * dt)
        ship.position = moveAtEdge(nextShipPosition, velocity: &velocity, margin: 15)
        ship.alpha = elapsed < protectedUntil && Int(elapsed * 10).isMultiple(of: 2) ? 0.25 : 1

        if held.contains(49) && shiftHeld && beamBattery.charges > 0 {
            if elapsed - lastBeamFire >= BeamBattery.fireInterval && beamBattery.fire() {
                lastBeamFire = elapsed
                fireBeam(direction: forward)
            }
        } else if held.contains(49) &&
            elapsed - lastFire > CGFloat(customRules?.shotInterval ?? Double(difficulty.shootCooldown)) &&
            lasers.count < (customRules?.maxBullets ?? 6) && ammo.fire() {
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
                                remaining: CGFloat(customRules?.bulletLifetime ?? Double(difficulty.bulletLifetime))))
        }

        updateBlackHole(dt)
        if modern {
            let density = beltDensity(at: elapsed)
            backgroundLayer?.animate(time: elapsed, density: density,
                                     shipVelocity: velocity, thrusting: thrusting)
            updateBeltTraffic(density: density)
        }
        for i in boulders.indices {
            let next = CGPoint(x: boulders[i].node.position.x + boulders[i].velocity.dx * dt,
                               y: boulders[i].node.position.y + boulders[i].velocity.dy * dt)
            boulders[i].node.position = moveAtEdge(
                next, velocity: &boulders[i].velocity, margin: boulders[i].radius)
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

        // Retain the bullet's previous position for continuous collision detection.
        // Point-only tests can tunnel through thin station geometry at high speed.
        let laserStarts = lasers.map { $0.node.position }
        for i in lasers.indices {
            lasers[i].remaining -= dt
            let next = CGPoint(x: lasers[i].node.position.x + lasers[i].velocity.dx * dt,
                               y: lasers[i].node.position.y + lasers[i].velocity.dy * dt)
            lasers[i].node.position = moveAtEdge(next, velocity: &lasers[i].velocity, margin: 0)
        }

        if (customRules?.cometEnabled ?? (modern || difficulty == .hard)) {
            updateComet(dt)
        }
        updateNuclearMissile(dt)
        updateShockwaves(dt)
        updateOrbitalTraffic(dt)
        if customRules?.saucerEnabled ?? true { updateSaucer(dt) }
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
            if let activeSatellite = satellite,
               hypot(activeSatellite.node.position.x - lasers[i].node.position.x,
                     activeSatellite.node.position.y - lasers[i].node.position.y) < 31 {
                lasers.remove(at: i).node.removeFromParent()
                destroySatellite(at: activeSatellite.node.position)
                continue
            }
            if let activeStation = station,
               let impact = stationImpact(from: laserStarts[i],
                                          to: lasers[i].node.position,
                                          station: activeStation) {
                lasers.remove(at: i).node.removeFromParent()
                damageStation(at: impact)
                continue
            }
            if let activeSaucer = saucer, activeSaucer.decloakRemaining <= 0,
               hypot(activeSaucer.node.position.x - lasers[i].node.position.x,
                     activeSaucer.node.position.y - lasers[i].node.position.y) < 29 {
                lasers.remove(at: i).node.removeFromParent()
                destroySaucer()
                continue
            }
            if let j = boulders.firstIndex(where: {
                hypot($0.node.position.x - lasers[i].node.position.x,
                      $0.node.position.y - lasers[i].node.position.y) < $0.radius + 2
            }) {
                lasers.remove(at: i).node.removeFromParent()
                damageRock(at: j)
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
                $0.decloakRemaining <= 0 &&
                hypot($0.node.position.x - ship.position.x,
                      $0.node.position.y - ship.position.y) < 34
            } ?? false)) {
            destroyPlayerShip()
        }
        if boulders.isEmpty && shockwaves.isEmpty {
            wave += 1
            // Enter a visually distinct region of space every wave.
            // An individual new game already regenerates through updateStyle().
            if modern { backgroundLayer?.regenerate() }
            // Shields recharge on their own, not just at a wave boundary.
            missilesRemaining = customRules?.missilesPerWave ?? 2
            spawnWave()
            ArcadeAudio.shared.play(.wave)
            protectedUntil = elapsed + 1.5
            updateHud()
        }
    }

    /// A restrained, bounded camera impulse reserved for significant events.
    /// Re-entrant triggers are rate-limited to avoid jitter during beam fire.
    private func shakeForImpact(_ strength: CGFloat) {
        guard modern, elapsed - lastImpactShake > 0.26 else { return }
        lastImpactShake = elapsed
        let origin = CGPoint(x: size.width / 2, y: size.height / 2)
        let amount = min(max(strength, 1), 4.5)
        feedbackCamera.removeAction(forKey: "impactShake")
        feedbackCamera.position = origin
        let offsets = [CGVector(dx: amount, dy: amount * 0.3),
                       CGVector(dx: -amount * 0.65, dy: -amount * 0.6),
                       CGVector(dx: amount * 0.3, dy: amount * 0.25)]
        let actions = offsets.map { delta in
            SKAction.move(to: CGPoint(x: origin.x + delta.dx,
                                      y: origin.y + delta.dy), duration: 0.035)
        }
        feedbackCamera.run(.sequence(actions + [
            .move(to: origin, duration: 0.055)
        ]), withKey: "impactShake")
    }

    /// One death path handles rock collisions and nuclear splash damage.
    /// The nuke deliberately bypasses shield and respawn protection, but
    /// never subtracts multiple lives during the same death animation.
    private func destroyPlayerShip() {
        guard !over, !titleVisible, !ship.isHidden else { return }
        lives -= 1
        ArcadeAudio.shared.stopThrust()
        if shieldActive { startShieldRecharge() }
        ArcadeAudio.shared.play(.ship)
        shakeForImpact(4.5)
        shipImpact()
        updateHud()
        if lives <= 0 {
            over = true
            ship.isHidden = true
            saveFinalScore()
            message.text = "GAME OVER"
            stageHeading.text = "FLIGHT TERMINATED    //    SIMULATION END"
            stageCaption.text = "PRESS RETURN TO RESTART"
            stagePanel.isHidden = false
            stageHeading.isHidden = false
            stageCaption.isHidden = false
        } else {
            resetShip()
            protectedUntil = elapsed + difficulty.respawnProtection
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

    private func startShieldRecharge() {
        shieldActive = false
        shieldNode.isHidden = true
        shieldEnergy = 0
        shieldRechargeRemaining = CGFloat(customRules?.shieldCooldown ?? Double(difficulty.shieldCooldown))
    }

    private func hyperspace() {
        guard elapsed - lastWarp > difficulty.hyperspaceCooldown else { return }
        lastWarp = elapsed
        ship.position = CGPoint(x: .random(in: 40...max(41, size.width - 40)),
                                y: .random(in: 40...max(41, size.height - 40)))
        velocity = .zero
        protectedUntil = elapsed + 1.4
        if modern { backgroundLayer?.warpBurst() }
    }

    /// Asteroid belts are patchy. Built-in Modern games move through
    /// lighter and denser lanes while custom presets retain their exact count.
    private func beltDensity(at time: CGFloat) -> CGFloat {
        let broad = sin(time * 0.075 + CGFloat(wave) * 0.9)
        let pockets = sin(time * 0.21 - CGFloat(wave) * 0.42)
        return max(0, min(1, 0.50 + broad * 0.35 + pockets * 0.15))
    }

    private func updateBeltTraffic(density: CGFloat) {
        guard customRules == nil, wave >= 2, density > 0.68,
              boulders.count >= 4, elapsed - lastBeltSpawn > 8.5 else { return }
        let waveCount = difficulty.rockCount(forWave: wave)
        guard boulders.count < min(27, waveCount + 3) else { return }
        lastBeltSpawn = elapsed

        // A single distant rock enters from the edge, instead of spawning
        // directly on the ship. No continuous spawning when a wave is cleared.
        let level = min(difficulty.maximumRockLevel, Bool.random() ? 2 : 3)
        let radius = rockRadius(for: level)
        let fromLeft = Bool.random()
        let y = CGFloat.random(in: (size.height * 0.17)...(size.height * 0.83))
        let x = fromLeft ? -radius : size.width + radius
        let direction = fromLeft
            ? CGFloat.random(in: -0.38...0.38)
            : CGFloat.pi + CGFloat.random(in: -0.38...0.38)
        let speed = rockSpeed(for: level)
        spawnRock(level: level, at: CGPoint(x: x, y: y),
                  velocity: CGVector(dx: cos(direction) * speed,
                                     dy: sin(direction) * speed))
    }

    private func spawnWave() {
        let baseCount = customRules?.rockCount(wave: wave) ??
            difficulty.rockCount(forWave: wave)
        let laneFactor: CGFloat = modern && customRules == nil
            ? (0.78 + beltDensity(at: elapsed) * 0.53) : 1.0
        let count = min(30, max(1, Int((CGFloat(baseCount) * laneFactor).rounded())))
        lastBeltSpawn = elapsed
        for index in 0..<count {
            let level = customRules?.initialRockLevel(at: index) ??
                difficulty.startingRockLevel(at: index)
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
        let multiplier = CGFloat(customRules?.asteroidSpeed ?? Double(difficulty.speedMultiplier))
        return CGFloat.random(in: baseRange) * multiplier * waveFactor
    }

    /// A player shot and the delayed fracture use exactly the same
    /// split progression. Automatic fractures award no points.
    private func fragmentRock(at index: Int, byPlayer: Bool) {
        let rock = boulders.remove(at: index)
        let position = rock.node.position
        rock.node.removeFromParent()
        ArcadeAudio.shared.playRockBreak(level: rock.level)
        if rock.level >= 3 { shakeForImpact(rock.level >= 5 ? 3.2 : 1.8) }
        if modern {
            ModernVisuals.fractureBurst(in: self, at: position,
                                        radius: rock.radius, intensity: rock.level)
            ModernVisuals.wreckage(in: self, at: position,
                                   size: max(8, rock.radius * 0.75),
                                   color: ModernVisuals.ice,
                                   pieces: min(6, 2 + rock.level))
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
            for spread in [-0.75, 0.75] as [CGFloat] {
                let angle = travelAngle + spread
                let speed = rockSpeed(for: nextLevel)
                spawnRock(level: nextLevel, at: position,
                          velocity: CGVector(dx: cos(angle) * speed,
                                             dy: sin(angle) * speed))
            }
        }
    }

    /// Both regular bullets and the Shift laser use the same staged
    /// asteroid fracture behavior. One ray damages each encountered rock once.
    private func damageRock(at j: Int) {
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
                ModernVisuals.hitMarker(in: self, at: rock.node.position,
                                        radius: max(8, rock.radius * 0.48),
                                        color: damageStage > 1 ? .systemRed : .systemOrange)
            }
            return // No change in radius until final shot or countdown.
        }
        fragmentRock(at: j, byPlayer: true)
    }

    private func fireBeam(direction: CGVector) {
        // Clamp beam to the visible playfield instead of allowing a path to
        // extend into an adjacent wrapped edge. Multiple rocks can be hit.
        let origin = CGPoint(x: ship.position.x + direction.dx * 19,
                             y: ship.position.y + direction.dy * 19)
        let xTravel = direction.dx > 0.0001 ? (size.width - origin.x) / direction.dx :
                      direction.dx < -0.0001 ? -origin.x / direction.dx : CGFloat.greatestFiniteMagnitude
        let yTravel = direction.dy > 0.0001 ? (size.height - origin.y) / direction.dy :
                      direction.dy < -0.0001 ? -origin.y / direction.dy : CGFloat.greatestFiniteMagnitude
        let distance = max(0, min(xTravel, yTravel, hypot(size.width, size.height)))
        let endpoint = CGPoint(x: origin.x + direction.dx * distance,
                               y: origin.y + direction.dy * distance)
        let ray = CGMutablePath()
        ray.move(to: origin)
        ray.addLine(to: endpoint)
        let halo = SKShapeNode(path: ray)
        halo.strokeColor = modern ? .systemCyan : .white
        halo.lineWidth = modern ? 12 : 5
        halo.alpha = modern ? 0.30 : 0.18
        halo.glowWidth = modern ? 18 : 0
        halo.zPosition = 25
        addChild(halo)
        let core = SKShapeNode(path: ray)
        core.strokeColor = .white
        core.lineWidth = modern ? 3 : 2
        core.glowWidth = modern ? 9 : 0
        core.zPosition = 26
        addChild(core)
        for node in [halo, core] {
            node.run(.sequence([.wait(forDuration: Double(BeamBattery.beamSeconds)),
                                .removeFromParent()]))
        }
        ArcadeAudio.shared.play(.beam)

        func hits(_ point: CGPoint, radius: CGFloat) -> Bool {
            let deltaX = point.x - origin.x
            let deltaY = point.y - origin.y
            let along = deltaX * direction.dx + deltaY * direction.dy
            guard along >= 0 && along <= distance else { return false }
            let cross = abs(deltaX * direction.dy - deltaY * direction.dx)
            return cross <= radius + (modern ? 3 : 2)
        }

        if let target = comet, hits(target.node.position, radius: 19) {
            detonateComet(at: target.node.position)
        }
        if let target = satellite, hits(target.node.position, radius: 28) {
            destroySatellite(at: target.node.position)
        }
        if let target = station, hits(target.node.position, radius: 135 * target.node.xScale) {
            damageStation(at: target.node.position, force: 2)
        }
        if let target = saucer, target.decloakRemaining <= 0,
           hits(target.node.position, radius: 27) {
            destroySaucer()
        }
        let originals = boulders.count
        if originals > 0 {
            for i in stride(from: originals - 1, through: 0, by: -1) {
                if hits(boulders[i].node.position, radius: boulders[i].radius) {
                    damageRock(at: i)
                }
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
        let surface = ModernRockTextures.create(radius: radius, outline: points)
        node.addChild(surface)
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
        let hitPoints = customRules?.hits(level: level, difficulty: difficulty.rawValue) ??
            difficulty.hitsToSplit(level: level)
        let spinSpeed = CGFloat.random(in: -1.2...1.2) /
            (1 + CGFloat(max(level - 3, 0)) * 0.5)
        boulders.append(Boulder(node: node, velocity: velocity, radius: radius,
                                level: level, spin: spinSpeed, detail: detail,
                                hitPoints: hitPoints, maximumHitPoints: hitPoints,
                                crack: crack, secondCrack: secondCrack,
                                lastShieldImpact: -10, fractureRemaining: nil,
                                fractureDuration: 0, fractureRing: fractureRing,
                                surface: surface))
        styleRock(node, detail: detail)
    }

    private func updateHud() {
        hud.text = String(format: "%06d", score)
        leftFootnote.text = String(format: "BEST  %06d", high)
        waveValue.text = String(format: "%02d", wave)
        let density = Int((beltDensity(at: elapsed) * 100).rounded())
        beltCaption.text = modern ? "BELT DENSITY" : "FLIGHT PROFILE"
        beltValue.text = modern ? String(format: "%02d%%", density) : "CLASSIC"
        let shieldStatus: String
        if shieldActive {
            shieldStatus = String(format: "SHIELD %.1fs", shieldEnergy)
        } else if shieldRechargeRemaining > 0 {
            shieldStatus = String(format: "RECHARGING %.1fs", shieldRechargeRemaining)
        } else {
            shieldStatus = "SHIELD READY [S]"
        }
        statusHUD.text = String(format: "%02d LIVES  ·  %02d NUKES", lives, missilesRemaining)
        rightFootnote.text = shieldStatus
        difficultyReadout.text = "MODE  " + difficulty.title.uppercased() +
            (nuclearMissile == nil ? "" : "  ·  MISSILE AWAY")
        ammoReadout.text = String(format: "ROUNDS  %03d / %03d",
                                  ammo.rounds, AmmoReserve.capacity)
        ammoStatus.text = ammo.rechargeStatus(secondsSinceShot: elapsed - lastFire)
        beamStatus.text = beamBattery.statusText
    }

    private func updateStyle() {
        guard ready else { return }
        // Opaque scene and sprite guarantees never rely on SKView's
        // default white/transparent clear color.
        let darkSpace = SKColor(calibratedRed: 0.005, green: 0.009, blue: 0.025, alpha: 1)
        backgroundColor = modern ? darkSpace : .black
        spaceBackdrop.color = modern ? darkSpace : .black
        let color: SKColor = modern ? .cyan : .white
        ship.strokeColor = color
        ship.glowWidth = modern ? 5 : 0
        hud.fontColor = color
        statusHUD.fontColor = modern ? ModernVisuals.ice : .white
        message.fontColor = color
        stagePanel.fillColor = modern
            ? SKColor(calibratedRed: 0.035, green: 0.085, blue: 0.13, alpha: 0.22)
            : SKColor(calibratedWhite: 0.06, alpha: 0.20)
        stagePanel.strokeColor = modern
            ? SKColor(calibratedRed: 0.94, green: 0.72, blue: 0.44, alpha: 0.25)
            : SKColor(calibratedWhite: 0.92, alpha: 0.24)
        rightPanel.fillColor = modern
            ? SKColor(calibratedRed: 0.035, green: 0.085, blue: 0.13, alpha: 0.13)
            : SKColor(calibratedWhite: 0.08, alpha: 0.12)
        rightPanel.strokeColor = modern
            ? SKColor(calibratedRed: 0.84, green: 0.68, blue: 0.44, alpha: 0.19)
            : SKColor(calibratedWhite: 0.8, alpha: 0.16)
        waveValue.fontColor = color
        beltValue.fontColor = color
        ammoReadout.fontColor = color
        beamStatus.fontColor = beamBattery.charges > 0
            ? (modern ? .systemMint : .white) : .systemOrange
        for rock in boulders {
            styleRock(rock.node, detail: rock.detail)
            rock.surface.isHidden = !modern
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
            ArcadeEffects.styleRaider(saucer.node, modern: modern)
        }
        modernShipDetail.isHidden = !modern
        flame.isHidden = true
        // Simple dark-space stars remain available as a fallback until the
        // first deferred Modern texture generation completes.
        classicTitleStars.isHidden = !titleVisible
        // Keep the procedural scene alive during graphics-mode changes.
        // Recreating multiple shader textures on each toggle could render an
        // empty or white background until gameplay began.
        if modern {
            if backgroundLayer == nil {
                backgroundLayer = VectorNebulaField(size: size)
            }
            if let layer = backgroundLayer {
                if layer.parent !== self {
                    layer.removeFromParent()
                    addChild(layer)
                }
                layer.resize(to: size)
                layer.isHidden = false
                layer.lens(at: blackHole?.node.position)
            }
        } else {
            backgroundLayer?.isHidden = true
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
        // Mode switching while on the title screen must update the value
        // readouts immediately; previously they could still say CLASSIC.
        updateHud()
    }

    private func styleRock(_ node: SKShapeNode, detail: SKNode) {
        detail.isHidden = !modern
        for child in node.children where child is SKSpriteNode {
            child.isHidden = !modern
        }
        node.strokeColor = modern ? SKColor(calibratedRed: 0.54, green: 0.73, blue: 0.83, alpha: 1) : .white
        node.fillColor = .clear
        node.glowWidth = modern ? 1.4 : 0
        node.lineWidth = modern ? 1.1 : 1.7
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
        blackHole?.node.removeFromParent()
        blackHole = nil
        backgroundLayer?.lens(at: nil)
        nuclearMissile?.node.removeFromParent()
        nuclearMissile = nil
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

    /// A rare gravity well. Far from its center the ship can thrust away;
    /// within the event horizon, shields offer no protection.
    private func updateBlackHole(_ dt: CGFloat) {
        guard customRules?.blackHoleEnabled ?? true else {
            blackHole?.node.removeFromParent()
            blackHole = nil
            backgroundLayer?.lens(at: nil)
            return
        }
        if blackHole == nil && wave >= 3 && elapsed - lastBlackHole >= nextBlackHoleDelay {
            spawnBlackHole()
        }
        guard var hole = blackHole else { return }
        hole.remaining -= dt
        if hole.remaining <= 0 {
            hole.node.removeFromParent()
            blackHole = nil
            backgroundLayer?.lens(at: nil)
            lastBlackHole = elapsed
            nextBlackHoleDelay = CGFloat.random(in: 25...42)
            return
        }
        blackHole = hole
        if let artwork = hole.node as? ModernBlackHoleNode {
            artwork.advance(dt: dt, remaining: hole.remaining)
        }
        let center = hole.node.position
        if modern {
            backgroundLayer?.lens(at: center, intensity: min(1, hole.remaining / 1.2))
        }

        func pull(at point: CGPoint) -> CGVector {
            let dx = center.x - point.x, dy = center.y - point.y
            let d = max(1, hypot(dx, dy))
            guard d < 370 else { return .zero }
            let acceleration = min(1050, 100000 / max(95, d))
            return CGVector(dx: dx / d * acceleration * dt,
                            dy: dy / d * acceleration * dt)
        }
        if !ship.isHidden && !over {
            let a = pull(at: ship.position)
            velocity.dx += a.dx
            velocity.dy += a.dy
            if hypot(center.x - ship.position.x, center.y - ship.position.y) < 19 {
                shieldActive = false
                shieldNode.isHidden = true
                lives -= 1
                ArcadeAudio.shared.stopThrust()
                ArcadeAudio.shared.play(.ship)
                shipImpact()
                if lives <= 0 {
                    over = true
                    saveFinalScore()
                    message.text = "GAME OVER  •  PRESS RETURN"
                    stagePanel.isHidden = false
                } else {
                    resetShip()
                    protectedUntil = elapsed + difficulty.respawnProtection
                }
                updateHud()
            }
        }
        for i in boulders.indices.reversed() {
            let a = pull(at: boulders[i].node.position)
            boulders[i].velocity.dx += a.dx
            boulders[i].velocity.dy += a.dy
            if hypot(center.x - boulders[i].node.position.x,
                     center.y - boulders[i].node.position.y) < 20 {
                boulders.remove(at: i).node.removeFromParent()
            }
        }
        for i in lasers.indices.reversed() {
            let a = pull(at: lasers[i].node.position)
            lasers[i].velocity.dx += a.dx
            lasers[i].velocity.dy += a.dy
            if hypot(center.x - lasers[i].node.position.x,
                     center.y - lasers[i].node.position.y) < 18 {
                lasers.remove(at: i).node.removeFromParent()
            }
        }
        for i in enemyShots.indices.reversed() {
            let a = pull(at: enemyShots[i].node.position)
            enemyShots[i].velocity.dx += a.dx
            enemyShots[i].velocity.dy += a.dy
            if hypot(center.x - enemyShots[i].node.position.x,
                     center.y - enemyShots[i].node.position.y) < 18 {
                enemyShots.remove(at: i).node.removeFromParent()
            }
        }
        if var missile = nuclearMissile {
            let a = pull(at: missile.node.position)
            missile.velocity.dx += a.dx
            missile.velocity.dy += a.dy
            nuclearMissile = missile
        }
    }

    private func spawnBlackHole() {
        let node: SKNode = modern ? ModernBlackHoleNode() : BlackHoleArtwork.classic()
        node.position = CGPoint(
            x: CGFloat.random(in: (size.width * 0.20)...(size.width * 0.80)),
            y: CGFloat.random(in: (size.height * 0.20)...(size.height * 0.80)))
        node.zPosition = 8
        addChild(node)
        blackHole = BlackHoleEvent(node: node, remaining: 11)
        ArcadeAudio.shared.play(.comet)
    }

    private func launchNuclearMissile() {
        guard missilesRemaining > 0, nuclearMissile == nil, !over, !titleVisible else { return }
        missilesRemaining -= 1
        let direction = CGVector(dx: -sin(heading), dy: cos(heading))
        let missile = SKShapeNode(ellipseOf: CGSize(width: 11, height: 19))
        missile.fillColor = modern ? ModernVisuals.fire : .black
        missile.strokeColor = modern ? .yellow : .white
        missile.lineWidth = 2
        missile.glowWidth = modern ? 12 : 0
        missile.zRotation = heading
        missile.position = CGPoint(x: ship.position.x + direction.dx * 35,
                                   y: ship.position.y + direction.dy * 35)
        missile.zPosition = 10
        addChild(missile)
        nuclearMissile = NuclearMissile(node: missile,
            velocity: CGVector(dx: velocity.dx * 0.65 + direction.dx * 295,
                               dy: velocity.dy * 0.65 + direction.dy * 295),
            fuse: 2.0)
        ArcadeAudio.shared.play(.fire)
        updateHud()
    }

    private func updateNuclearMissile(_ dt: CGFloat) {
        guard var missile = nuclearMissile else { return }
        missile.fuse -= dt
        missile.node.position = wrapped(
            CGPoint(x: missile.node.position.x + missile.velocity.dx * dt,
                    y: missile.node.position.y + missile.velocity.dy * dt), margin: 0)
        // Slowly decelerates so it appears to drift out from the ship.
        missile.velocity.dx *= max(0, 1 - dt * 0.12)
        missile.velocity.dy *= max(0, 1 - dt * 0.12)
        if modern && Int(elapsed * 18).isMultiple(of: 2) {
            ModernVisuals.cometSpark(in: self, at: missile.node.position,
                                     direction: missile.velocity)
        }
        if missile.fuse <= 0 {
            detonateNuclearMissile(at: missile.node.position)
        } else {
            nuclearMissile = missile
        }
    }

    private func detonateNuclearMissile(at point: CGPoint) {
        nuclearMissile?.node.removeFromParent()
        nuclearMissile = nil
        // A circle with ~33% of the playfield's area, before clipping.
        let blastArea = size.width * size.height * 0.33
        let radius = sqrt(blastArea / .pi)
        let ring = ModernVisuals.shockRing(at: point)
        ring.strokeColor = modern ? .yellow : .white
        ring.glowWidth = modern ? 28 : 0
        ring.lineWidth = 5
        addChild(ring)
        shockwaves.append(Shockwave(center: point, elapsed: 0,
                                    ring: ring, hit: [], maxRadius: radius))
        if modern {
            ModernVisuals.fractureBurst(in: self, at: point, radius: radius * 0.3, intensity: 5)
        }
        // Launch position matters: a nuke that detonates too close will
        // destroy its own ship, including through an active shield.
        // This lethal core is intentionally smaller than the full blast.
        let shipDistance = hypot(ship.position.x - point.x, ship.position.y - point.y)
        let lethalRadius = min(180, radius * 0.50)
        if shipDistance < lethalRadius {
            destroyPlayerShip()
        }

        // Destroy enemy hazards. Orbital station remains indestructible but sheds debris.
        if let target = satellite,
           hypot(target.node.position.x - point.x,
                 target.node.position.y - point.y) < radius {
            destroySatellite(at: target.node.position)
        }
        if let target = station,
           hypot(target.node.position.x - point.x,
                 target.node.position.y - point.y) < radius + 145 * target.node.xScale {
            damageStation(at: target.node.position, force: 3)
        }
        if let target = saucer, hypot(target.node.position.x - point.x,
                                      target.node.position.y - point.y) < radius {
            destroySaucer()
        }
        if let target = comet, hypot(target.node.position.x - point.x,
                                      target.node.position.y - point.y) < radius {
            target.node.removeFromParent()
            comet = nil
            lastComet = elapsed
        }
        for i in enemyShots.indices.reversed() {
            if hypot(enemyShots[i].node.position.x - point.x,
                     enemyShots[i].node.position.y - point.y) < radius {
                enemyShots.remove(at: i).node.removeFromParent()
            }
        }
        ArcadeAudio.shared.play(.nuclear)
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
                                    ring: ring, hit: Set<ObjectIdentifier>(),
                                    maxRadius: 350))
    }

    private func updateShockwaves(_ dt: CGFloat) {
        for i in shockwaves.indices.reversed() {
            shockwaves[i].elapsed += dt
            let progress = min(shockwaves[i].elapsed / 0.95, 1)
            let radius = shockwaves[i].maxRadius * progress
            shockwaves[i].ring.setScale(max(0.01, radius / 12))
            shockwaves[i].ring.alpha = 1 - progress

            if let target = satellite,
               hypot(target.node.position.x - shockwaves[i].center.x,
                     target.node.position.y - shockwaves[i].center.y) <= radius + 26 {
                destroySatellite(at: target.node.position)
            }
            if let target = station {
                let identity = ObjectIdentifier(target.node)
                if !shockwaves[i].hit.contains(identity),
                   hypot(target.node.position.x - shockwaves[i].center.x,
                         target.node.position.y - shockwaves[i].center.y) < radius + 145 * target.node.xScale {
                    shockwaves[i].hit.insert(identity)
                    damageStation(at: target.node.position, force: 2)
                }
            }
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

    private func clearOrbitalTraffic() {
        satellite?.node.removeFromParent()
        satellite = nil
        station?.node.removeFromParent()
        station = nil
        stationDamage = 0
    }

    /// Timeline-based orbital flybys, driven by game time (not wall time).
    /// Each new satellite is scheduled every twenty seconds. The station
    /// floats by less often. Hits can damage detachable structures but not its core.
    private func updateOrbitalTraffic(_ dt: CGFloat) {
        if elapsed >= nextSatelliteAt {
            while elapsed >= nextSatelliteAt { nextSatelliteAt += 20 }
            if satellite == nil { spawnSatellite() }
        }
        if elapsed >= nextStationAt {
            while elapsed >= nextStationAt { nextStationAt += 56 }
            if station == nil { spawnStation() }
        }

        if var object = satellite {
            object.remaining -= dt
            object.node.position.x += object.velocity.dx * dt
            object.node.position.y += object.velocity.dy * dt
            object.node.zRotation += dt * 0.16
            if object.remaining <= 0 ||
                object.node.position.x < -110 ||
                object.node.position.x > size.width + 110 ||
                object.node.position.y < -110 ||
                object.node.position.y > size.height + 110 {
                object.node.removeFromParent()
                satellite = nil
            } else {
                satellite = object
            }
        }
        if var object = station {
            object.remaining -= dt
            object.node.position.x += object.velocity.dx * dt
            object.node.position.y += object.velocity.dy * dt
            object.node.zRotation += dt * 0.018
            if object.remaining <= 0 ||
                object.node.position.x < -280 ||
                object.node.position.x > size.width + 280 ||
                object.node.position.y < -280 ||
                object.node.position.y > size.height + 280 {
                object.node.removeFromParent()
                station = nil
            } else {
                station = object
            }
        }
    }

    /// Spawn beyond one of all four sides, aiming across the playfield.
    /// The velocity points inward, so top/bottom entries remain fair and do
    /// not disappear immediately. Independently randomize destination/angle.
    private func orbitalRoute(speed: CGFloat, margin: CGFloat) ->
        (position: CGPoint, velocity: CGVector, lifetime: CGFloat) {
        let edge = Int.random(in: 0..<4)
        let width = max(size.width, 300)
        let height = max(size.height, 240)
        let start: CGPoint
        switch edge {
        case 0:
            start = CGPoint(x: -margin, y: CGFloat.random(in: height * 0.12...height * 0.88))
        case 1:
            start = CGPoint(x: width + margin, y: CGFloat.random(in: height * 0.12...height * 0.88))
        case 2:
            start = CGPoint(x: CGFloat.random(in: width * 0.12...width * 0.88), y: -margin)
        default:
            start = CGPoint(x: CGFloat.random(in: width * 0.12...width * 0.88), y: height + margin)
        }
        // Each entry has a different diagonal, not simply a four-way vector.
        let destination = CGPoint(x: CGFloat.random(in: width * 0.22...width * 0.78),
                                  y: CGFloat.random(in: height * 0.22...height * 0.78))
        let dx = destination.x - start.x
        let dy = destination.y - start.y
        let distance = max(1, hypot(dx, dy))
        let velocity = CGVector(dx: dx / distance * speed,
                                dy: dy / distance * speed)
        let lifetime = (hypot(width, height) * 2 + margin * 3) / max(speed, 1)
        return (start, velocity, lifetime)
    }

    private func spawnSatellite() {
        let node = ArcadeEffects.satellite(modern: modern)
        let speed = CGFloat.random(in: 105...145)
        let route = orbitalRoute(speed: speed, margin: 85)
        node.position = route.position
        node.zRotation = atan2(route.velocity.dy, route.velocity.dx)
        addChild(node)
        satellite = OrbitalTraffic(node: node, velocity: route.velocity,
                                   remaining: route.lifetime)
    }

    /// Manual runtime verification: place the current ISS asset near the ship,
    /// so testing cannot depend on waiting for a random flyby.
    func spawnTestStation() {
        guard ready else { return }
        station?.node.removeFromParent()
        station = nil
        stationDamage = 0
        let node = ArcadeEffects.station(modern: modern)
        node.position = CGPoint(x: size.width * 0.60, y: size.height * 0.55)
        node.setScale(1.116)
        addChild(node)
        station = OrbitalTraffic(node: node,
                                 velocity: .zero,
                                 remaining: 50)
        let note = SKLabelNode(fontNamed: "Menlo-Bold")
        note.text = "ISS TEST  •  SHOOT SOLAR ARRAYS"
        note.fontSize = 13
        note.fontColor = .systemCyan
        note.position = CGPoint(x: node.position.x, y: node.position.y + 124)
        note.zPosition = 16
        addChild(note)
        note.run(.sequence([.wait(forDuration: 3), .fadeOut(withDuration: 0.5),
                            .removeFromParent()]))
    }

    private func spawnStation() {
        stationDamage = 0
        let node = ArcadeEffects.station(modern: modern)
        node.setScale(CGFloat.random(in: 1.008...1.152))
        let speed = CGFloat.random(in: 48...70)
        let route = orbitalRoute(speed: speed, margin: 270)
        node.position = route.position
        node.zRotation = CGFloat.random(in: -0.18...0.18)
        addChild(node)
        station = OrbitalTraffic(node: node, velocity: route.velocity,
                                 remaining: route.lifetime)
    }

    /// Continuous segment-vs-rotated-hull intersection in station coordinates.
    /// This catches fast bullets crossing the station between rendered frames.
    private func stationImpact(from start: CGPoint, to end: CGPoint,
                               station target: OrbitalTraffic) -> CGPoint? {
        // Ignore only true edge-wrap jumps; ordinary fast bullets are tested.
        guard abs(end.x - start.x) < size.width * 0.75,
              abs(end.y - start.y) < size.height * 0.75 else { return nil }
        let a = target.node.convert(start, from: self)
        let b = target.node.convert(end, from: self)
        let dx = b.x - a.x
        let dy = b.y - a.y
        var near: CGFloat = 0
        var far: CGFloat = 1

        // A little padding makes a clear visual hit reliable on narrow struts.
        // Encompass the ISS truss AND elevated upper/lower solar wings.
        for (origin, delta, extent) in [(a.x, dx, CGFloat(145)),
                                        (a.y, dy, CGFloat(78))] {
            if abs(delta) < 0.0001 {
                if abs(origin) > extent { return nil }
            } else {
                let entry = (-extent - origin) / delta
                let exit = (extent - origin) / delta
                near = max(near, min(entry, exit))
                far = min(far, max(entry, exit))
                if near > far { return nil }
            }
        }
        let localImpact = CGPoint(x: a.x + dx * near, y: a.y + dy * near)
        return target.node.convert(localImpact, to: self)
    }

    /// Impact scars and breakaway pieces progress without ever removing the
    /// central station. Debris has its own velocity and expires off-screen.
    private func damageStation(at impact: CGPoint, force: Int = 1) {
        guard let target = station else { return }
        let previous = stationDamage
        stationDamage = min(8, stationDamage + force)
        let local = target.node.convert(impact, from: self)
        let spark = SKShapeNode(circleOfRadius: 4)
        spark.position = local
        spark.fillColor = modern ? .systemOrange : .white
        spark.strokeColor = .clear
        spark.glowWidth = modern ? 13 : 2
        spark.zPosition = 8
        target.node.addChild(spark)
        target.node.run(.sequence([.fadeAlpha(to: 0.4, duration: 0.07),
                                   .fadeAlpha(to: 0.94, duration: 0.15)]))
        spark.run(.sequence([.group([.scale(to: 3.8, duration: 0.25),
                                     .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
        if modern {
            ModernVisuals.burst(in: self, at: impact, color: .systemOrange, count: 24)
        }
        let impactRing = SKShapeNode(circleOfRadius: 12)
        impactRing.position = impact
        impactRing.strokeColor = .systemOrange
        impactRing.lineWidth = 3.5
        impactRing.glowWidth = modern ? 13 : 0
        impactRing.zPosition = 15
        addChild(impactRing)
        impactRing.run(.sequence([.group([
            .scale(to: 3.4, duration: 0.34),
            .fadeOut(withDuration: 0.34)
        ]), .removeFromParent()]))
        ArcadeAudio.shared.playRockBreak(level: 1)
        shakeForImpact(force > 1 ? 2.2 : 1.0)
        // Detach an entire, visible solar-array assembly on each early hit.
        // Only four detachable arrays exist. Clamp both range endpoints:
        // Swift traps when the lower bound exceeds the upper bound (hit 5+).
        let detachedBefore = min(max(previous, 0), 4)
        let detachedAfter = min(max(stationDamage, 0), 4)
        if detachedBefore < detachedAfter {
            for index in detachedBefore..<detachedAfter {
                releaseStationSection(named: "stationArray\(index)", from: target)
            }
        }
        if stationDamage > previous {
            let scar = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...7))
            scar.position = local
            scar.setScale(2.0)
            scar.fillColor = .black
            scar.strokeColor = modern ? .systemOrange.withAlphaComponent(0.8) : .gray
            scar.lineWidth = 1
            scar.zPosition = 3
            target.node.addChild(scar)
            // Bright, persistent impact mark plus debris on *every* shot.
            for _ in 0..<9 {
                let fragment = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 5...14), height: 3))
                fragment.position = impact
                fragment.fillColor = modern ? .gray : .white
                fragment.strokeColor = modern ? .systemCyan : .white
                fragment.zPosition = 7
                addChild(fragment)
                let delta = CGVector(dx: CGFloat.random(in: -140...140),
                                     dy: CGFloat.random(in: -110...110))
                fragment.run(.sequence([.group([
                    .moveBy(x: delta.dx, y: delta.dy, duration: 2.2),
                    .rotate(byAngle: CGFloat.random(in: -4...4), duration: 2.2),
                    .fadeOut(withDuration: 2.2)
                ]), .removeFromParent()]))
            }
        }
    }

    private func releaseStationSection(named name: String, from target: OrbitalTraffic) {
        guard let section = target.node.childNode(withName: name) else { return }
        let location = target.node.convert(section.position, to: self)
        section.removeFromParent()
        section.position = location
        section.zRotation = target.node.zRotation
        section.setScale(target.node.xScale)
        section.zPosition = 6
        addChild(section)
        section.run(.sequence([.group([
            .moveBy(x: CGFloat.random(in: -220...220),
                    y: CGFloat.random(in: -165...165), duration: 4.0),
            .rotate(byAngle: CGFloat.random(in: -3.5...3.5), duration: 4.0),
            .fadeOut(withDuration: 4.0)
        ]), .removeFromParent()]))
    }

    private func destroySatellite(at point: CGPoint) {
        guard let target = satellite else { return }
        target.node.removeFromParent()
        satellite = nil
        award(350)
        shakeForImpact(2.7)
        ArcadeAudio.shared.playRockBreak(level: 4)
        if modern {
            ModernVisuals.burst(in: self, at: point, color: ModernVisuals.ice, count: 29)
            ModernVisuals.burst(in: self, at: point, color: .systemOrange, count: 19)
            ModernVisuals.floatScore("SATELLITE +350", in: self, at: point)
        } else {
            ModernVisuals.burst(in: self, at: point, color: .white, count: 20)
        }
        let flash = SKShapeNode(circleOfRadius: 11)
        flash.position = point
        flash.fillColor = modern ? .systemCyan : .white
        flash.strokeColor = .clear
        flash.glowWidth = modern ? 22 : 0
        flash.zPosition = 14
        addChild(flash)
        flash.run(.sequence([
            .group([.scale(to: 4, duration: 0.38), .fadeOut(withDuration: 0.38)]),
            .removeFromParent()
        ]))
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
        enemy.node.position.y += enemy.velocity.dy * dt
        // Keep evasive movement, but do not clamp top/bottom entries to the
        // screen edge. Flight direction stays predominantly inward.
        let wobble = sin(elapsed * 3.4) * 18 * dt
        let lateral = CGVector(dx: -enemy.velocity.dy, dy: enemy.velocity.dx)
        let speed = max(1, hypot(lateral.dx, lateral.dy))
        enemy.node.position.x += lateral.dx / speed * wobble
        enemy.node.position.y += lateral.dy / speed * wobble
        if enemy.node.position.x > 30 && enemy.node.position.x < size.width - 30 &&
           enemy.node.position.y > 30 && enemy.node.position.y < size.height - 30 {
            let pursuit = CGPoint(x: ship.position.x - enemy.node.position.x,
                                  y: ship.position.y - enemy.node.position.y)
            let norm = max(1, hypot(pursuit.x, pursuit.y))
            enemy.node.position.x += pursuit.x / norm * 9 * dt
            enemy.node.position.y += pursuit.y / norm * 9 * dt
        }
        if enemy.decloakRemaining > 0 {
            enemy.decloakRemaining = max(0, enemy.decloakRemaining - dt)
        } else {
            let interval: CGFloat = difficulty == .hard ? 1.05 :
                                     difficulty == .medium ? 1.65 : 2.45
            if elapsed - lastSaucerShot >= interval && enemyShots.count < 22 {
                lastSaucerShot = elapsed
                fireSaucerVolley(from: enemy.node.position)
                ArcadeAudio.shared.play(.saucer)
            }
        }
        if enemy.remaining <= 0 ||
           enemy.node.position.x < -75 || enemy.node.position.x > size.width + 75 ||
           enemy.node.position.y < -75 || enemy.node.position.y > size.height + 75 {
            enemy.node.removeFromParent()
            saucer = nil
            lastSaucer = elapsed
            nextSaucerDelay = CGFloat.random(in: difficulty.saucerDelay)
        } else {
            saucer = enemy
        }
    }

    private func spawnSaucer() {
        let node = ArcadeEffects.saucer(modern: modern)
        let speed = CGFloat.random(in: 92...132) * difficulty.speedMultiplier
        let route = orbitalRoute(speed: speed, margin: 48)
        node.position = route.position
        node.zRotation = atan2(route.velocity.dy, route.velocity.dx)
        if route.velocity.dx < 0 { node.xScale = -1 }
        node.alpha = 0.05
        addChild(node)
        // Non-collidable until the shimmer resolves; the enemy appears as
        // though a cloak is losing stability, then becomes fully visible.
        node.run(.sequence([
            .fadeAlpha(to: 0.34, duration: 0.22),
            .fadeAlpha(to: 0.10, duration: 0.13),
            .fadeAlpha(to: 0.62, duration: 0.24),
            .fadeAlpha(to: 0.25, duration: 0.12),
            .fadeAlpha(to: 1.0, duration: 0.39)
        ]))
        let ripple = SKShapeNode(circleOfRadius: 38)
        ripple.fillColor = .clear
        ripple.strokeColor = modern ? .systemPink : .white
        ripple.lineWidth = 1.5
        ripple.alpha = 0.55
        ripple.glowWidth = modern ? 8 : 0
        node.addChild(ripple)
        ripple.run(.sequence([
            .group([.scale(to: 1.45, duration: 1.10),
                    .fadeOut(withDuration: 1.10)]),
            .removeFromParent()
        ]))
        saucer = Saucer(node: node,
                        velocity: route.velocity,
                        remaining: route.lifetime,
                        decloakRemaining: 1.10)
        lastSaucerShot = elapsed
    }

    /// Small, difficulty-scaled aimed volleys with a modest lead on the ship.
    /// Easy remains a single forgiving projectile; Hard fires a three-shot
    /// fan without saturating the whole screen.
    private func fireSaucerVolley(from origin: CGPoint) {
        let count = difficulty == .hard ? 3 : difficulty == .medium ? 2 : 1
        let speed: CGFloat = difficulty == .hard ? 270 :
                              difficulty == .medium ? 225 : 175
        let prediction: CGFloat = difficulty == .hard ? 0.42 :
                                  difficulty == .medium ? 0.28 : 0.12
        let predicted = CGPoint(
            x: ship.position.x + velocity.dx * prediction,
            y: ship.position.y + velocity.dy * prediction
        )
        let base = atan2(predicted.y - origin.y, predicted.x - origin.x)
        let spread: CGFloat = difficulty == .hard ? 0.16 :
                              difficulty == .medium ? 0.18 : 0.35
        for index in 0..<count {
            let offset = (CGFloat(index) - CGFloat(count - 1) / 2) * spread
            let jitter = CGFloat.random(in: -0.065...0.065)
            let angle = base + offset + jitter
            let bullet = SKShapeNode(circleOfRadius: difficulty == .hard ? 3.6 : 3.0)
            bullet.position = origin
            bullet.fillColor = modern ? .systemRed : .white
            bullet.strokeColor = .clear
            bullet.glowWidth = modern ? 9 : 0
            bullet.zPosition = 7
            let tail = CGMutablePath()
            tail.move(to: CGPoint(x: 0, y: 0))
            tail.addLine(to: CGPoint(x: -cos(angle) * 16,
                                     y: -sin(angle) * 16))
            let streak = SKShapeNode(path: tail)
            streak.strokeColor = modern ? .systemPink : .white
            streak.lineWidth = 1.8
            streak.alpha = 0.64
            bullet.addChild(streak)
            addChild(bullet)
            enemyShots.append(EnemyShot(
                node: bullet,
                velocity: CGVector(dx: cos(angle) * speed,
                                   dy: sin(angle) * speed),
                remaining: 2.5
            ))
        }
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
        award(300)
        shakeForImpact(4.2)
        ArcadeAudio.shared.play(.saucer)
        ArcadeAudio.shared.playRockBreak(level: 5)
        let primary = modern ? SKColor.systemRed : .white
        ModernVisuals.burst(in: self, at: position, color: primary,
                            count: modern ? 44 : 23)
        if modern {
            ModernVisuals.burst(in: self, at: position, color: .systemOrange, count: 24)
            ModernVisuals.floatScore("RAIDER +300", in: self, at: position)
            ModernVisuals.wreckage(in: self, at: position, size: 24,
                                   color: .systemRed, pieces: 9)
            ModernVisuals.hitMarker(in: self, at: position, radius: 22,
                                    color: .systemOrange)
        }
        for (index, radius) in [CGFloat(13), CGFloat(22)].enumerated() {
            let shock = SKShapeNode(circleOfRadius: radius)
            shock.position = position
            shock.strokeColor = index == 0 ? primary : .systemOrange
            shock.fillColor = .clear
            shock.glowWidth = modern ? 18 : 0
            shock.lineWidth = index == 0 ? 4 : 2
            shock.zPosition = 14
            addChild(shock)
            let duration: Double = index == 0 ? 0.45 : 0.68
            shock.run(.sequence([
                .group([.scale(to: index == 0 ? 4.5 : 3.5, duration: duration),
                        .fadeOut(withDuration: duration)]),
                .removeFromParent()
            ]))
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

    private func moveAtEdge(_ proposed: CGPoint, velocity v: inout CGVector,
                            margin: CGFloat) -> CGPoint {
        guard customRules?.edgeMode == .bounce else { return wrapped(proposed, margin: margin) }
        let limitX = max(margin + 1, size.width - margin)
        let limitY = max(margin + 1, size.height - margin)
        var p = proposed
        if p.x < margin { p.x = margin; v.dx = abs(v.dx) }
        if p.x > limitX { p.x = limitX; v.dx = -abs(v.dx) }
        if p.y < margin { p.y = margin; v.dy = abs(v.dy) }
        if p.y > limitY { p.y = limitY; v.dy = -abs(v.dy) }
        return p
    }

    private func snapshotPoint(_ p: CGPoint) -> SavedVector {
        SavedVector(x: Double(p.x), y: Double(p.y))
    }

    private func snapshotVelocity(_ v: CGVector) -> SavedVector {
        SavedVector(x: Double(v.dx), y: Double(v.dy))
    }

    private func point(_ v: SavedVector) -> CGPoint {
        CGPoint(x: v.x, y: v.y)
    }

    private func vector(_ v: SavedVector) -> CGVector {
        CGVector(dx: v.x, dy: v.y)
    }

    /// Returns a complete gameplay checkpoint rather than a score-only save.
    func makeSnapshot(activePresetID: String) -> GameSnapshot? {
        guard ready && !titleVisible && !over else { return nil }
        let rocks = boulders.map { rock in
            SavedRock(level: rock.level, position: snapshotPoint(rock.node.position),
                      velocity: snapshotVelocity(rock.velocity),
                      rotation: Double(rock.node.zRotation), spin: Double(rock.spin),
                      hitPoints: rock.hitPoints,
                      remainingFracture: rock.fractureRemaining.map(Double.init),
                      fractureDuration: Double(rock.fractureDuration),
                      vertices: [])
        }
        let shots = lasers.map {
            SavedProjectile(position: snapshotPoint($0.node.position),
                            velocity: snapshotVelocity($0.velocity),
                            remaining: Double($0.remaining))
        }
        let enemyBullets = enemyShots.map {
            SavedProjectile(position: snapshotPoint($0.node.position),
                            velocity: snapshotVelocity($0.velocity),
                            remaining: Double($0.remaining))
        }
        let cometState = comet.map {
            SavedMovingEnemy(position: snapshotPoint($0.node.position),
                             velocity: snapshotVelocity($0.velocity),
                             remaining: Double($0.remaining))
        }
        let saucerState = saucer.map {
            SavedMovingEnemy(position: snapshotPoint($0.node.position),
                             velocity: snapshotVelocity($0.velocity),
                             remaining: Double($0.remaining))
        }
        let missileState = nuclearMissile.map {
            SavedProjectile(position: snapshotPoint($0.node.position),
                            velocity: snapshotVelocity($0.velocity),
                            remaining: Double($0.fuse))
        }
        return GameSnapshot(
            version: 1, difficulty: difficulty.rawValue, modern: modern,
            activePresetID: activePresetID, customRules: customRules,
            score: score, lives: lives, wave: wave, elapsed: Double(elapsed),
            heading: Double(heading), shipPosition: snapshotPoint(ship.position),
            shipVelocity: snapshotVelocity(velocity),
            protectionRemaining: Double(max(0, protectedUntil - elapsed)),
            shieldActive: shieldActive, shieldRemaining: Double(shieldEnergy),
            shieldCooldownRemaining: Double(shieldRechargeRemaining),
            timeSinceShot: Double(elapsed - lastFire),
            timeSinceWarp: Double(elapsed - lastWarp),
            timeSinceComet: Double(elapsed - lastComet),
            nextCometDelay: Double(nextCometDelay),
            timeSinceSaucer: Double(elapsed - lastSaucer),
            nextSaucerDelay: Double(nextSaucerDelay),
            timeSinceSaucerShot: Double(elapsed - lastSaucerShot),
            rocks: rocks, bullets: shots, enemyBullets: enemyBullets,
            comet: cometState, saucer: saucerState,
            shockwaves: shockwaves.map {
                SavedShockwave(center: snapshotPoint($0.center),
                               elapsed: Double($0.elapsed))
            },
            blackHole: blackHole.map {
                SavedMovingEnemy(position: snapshotPoint($0.node.position),
                                 velocity: SavedVector(x: 0, y: 0),
                                 remaining: Double($0.remaining))
            }, timeSinceBlackHole: Double(elapsed - lastBlackHole),
            nextBlackHoleDelay: Double(nextBlackHoleDelay),
            missilesRemaining: missilesRemaining, missile: missileState,
            ammoReserve: ammo, beamBattery: beamBattery,
            satellite: satellite.map {
                SavedMovingEnemy(position: snapshotPoint($0.node.position),
                                 velocity: snapshotVelocity($0.velocity),
                                 remaining: Double($0.remaining))
            },
            station: station.map {
                SavedMovingEnemy(position: snapshotPoint($0.node.position),
                                 velocity: snapshotVelocity($0.velocity),
                                 remaining: Double($0.remaining))
            },
            secondsUntilSatellite: Double(max(0, nextSatelliteAt - elapsed)),
            secondsUntilStation: Double(max(0, nextStationAt - elapsed)),
            stationDamageCount: stationDamage,
            saucerDecloakRemaining: saucer.map { Double($0.decloakRemaining) }
        )
    }

    /// Restore positions, velocities, remaining lifetimes, damaged-rock
    /// timers, shield cooldown and active projectiles. Cosmetic rock surfaces
    /// are regenerated and may differ from their original appearance.
    func restore(_ snapshot: GameSnapshot) {
        guard snapshot.version == 1 else { return }
        customRules = snapshot.customRules?.validated()
        difficulty = Difficulty(rawValue: snapshot.difficulty) ?? .medium
        modern = snapshot.modern
        restart()
        boulders.forEach { $0.node.removeFromParent() }
        lasers.forEach { $0.node.removeFromParent() }
        clearSpecialEffects()
        clearEnemies()
        clearOrbitalTraffic()
        boulders.removeAll()
        lasers.removeAll()
        elapsed = CGFloat(snapshot.elapsed)
        lastTime = 0
        score = snapshot.score
        high = max(high, score)
        lives = snapshot.lives
        wave = snapshot.wave
        heading = CGFloat(snapshot.heading)
        ship.position = point(snapshot.shipPosition)
        ship.zRotation = heading
        velocity = vector(snapshot.shipVelocity)
        protectedUntil = elapsed + CGFloat(snapshot.protectionRemaining)
        shieldActive = snapshot.shieldActive
        shieldEnergy = CGFloat(snapshot.shieldRemaining)
        shieldRechargeRemaining = CGFloat(snapshot.shieldCooldownRemaining)
        shieldNode.isHidden = !shieldActive
        lastFire = elapsed - CGFloat(snapshot.timeSinceShot)
        ammo = snapshot.ammoReserve ?? AmmoReserve()
        ammo.normalize()
        beamBattery = snapshot.beamBattery ?? BeamBattery()
        beamBattery.normalize()
        lastBeamFire = elapsed - BeamBattery.fireInterval
        shiftHeld = false
        lastWarp = elapsed - CGFloat(snapshot.timeSinceWarp)
        lastComet = elapsed - CGFloat(snapshot.timeSinceComet)
        nextCometDelay = CGFloat(snapshot.nextCometDelay)
        lastSaucer = elapsed - CGFloat(snapshot.timeSinceSaucer)
        nextSaucerDelay = CGFloat(snapshot.nextSaucerDelay)
        lastSaucerShot = elapsed - CGFloat(snapshot.timeSinceSaucerShot)
        nextSatelliteAt = elapsed + CGFloat(snapshot.secondsUntilSatellite ?? 20)
        nextStationAt = elapsed + CGFloat(snapshot.secondsUntilStation ?? 36)
        stationDamage = min(8, max(0, snapshot.stationDamageCount ?? 0))
        missilesRemaining = snapshot.missilesRemaining
        lastBeltSpawn = elapsed
        lastBlackHole = elapsed - CGFloat(snapshot.timeSinceBlackHole)
        nextBlackHoleDelay = CGFloat(snapshot.nextBlackHoleDelay)
        titleVisible = false
        over = false
        stopped = false
        classicTitleStars.isHidden = true
        stageHeading.position = CGPoint(x: size.width / 2, y: size.height / 2 + 31)
        stageCaption.position = CGPoint(x: size.width / 2, y: size.height / 2 - 31)
        stagePanel.isHidden = true
        stageHeading.isHidden = true
        stageCaption.isHidden = true
        message.text = ""
        ship.isHidden = false

        for saved in snapshot.rocks {
            spawnRock(level: saved.level, at: point(saved.position),
                      velocity: vector(saved.velocity))
            let i = boulders.count - 1
            boulders[i].node.zRotation = CGFloat(saved.rotation)
            boulders[i].spin = CGFloat(saved.spin)
            boulders[i].hitPoints = saved.hitPoints
            boulders[i].fractureRemaining = saved.remainingFracture.map { CGFloat($0) }
            boulders[i].fractureDuration = CGFloat(saved.fractureDuration)
            let stage = boulders[i].maximumHitPoints - saved.hitPoints
            boulders[i].crack.isHidden = stage < 1
            boulders[i].secondCrack.isHidden = stage < 2
            updateFractureIndicator(at: i)
        }
        for saved in snapshot.bullets {
            let bullet = SKShapeNode(circleOfRadius: 2)
            bullet.position = point(saved.position)
            bullet.fillColor = modern ? .yellow : .white
            addChild(bullet)
            lasers.append(Laser(node: bullet, velocity: vector(saved.velocity),
                                remaining: CGFloat(saved.remaining)))
        }
        for saved in snapshot.enemyBullets {
            let bullet = SKShapeNode(circleOfRadius: 3)
            bullet.position = point(saved.position)
            bullet.fillColor = modern ? .systemPink : .white
            addChild(bullet)
            enemyShots.append(EnemyShot(node: bullet, velocity: vector(saved.velocity),
                                        remaining: CGFloat(saved.remaining)))
        }
        if let saved = snapshot.comet {
            let node = modern ? ModernVisuals.cometNode() : ArcadeEffects.classicComet()
            node.position = point(saved.position)
            let movement = vector(saved.velocity)
            node.zRotation = atan2(movement.dy, movement.dx)
            addChild(node)
            comet = Comet(node: node, velocity: movement, remaining: CGFloat(saved.remaining))
        }
        if let saved = snapshot.saucer {
            let node = ArcadeEffects.saucer(modern: modern)
            node.position = point(saved.position)
            if saved.velocity.x < 0 { node.xScale = -1 }
            let cloak = max(0, CGFloat(snapshot.saucerDecloakRemaining ?? 0))
            if cloak > 0 {
                node.alpha = 0.12
                node.run(.fadeIn(withDuration: Double(cloak)))
            }
            addChild(node)
            saucer = Saucer(node: node, velocity: vector(saved.velocity),
                            remaining: CGFloat(saved.remaining),
                            decloakRemaining: cloak)
        }
        if let saved = snapshot.satellite {
            let node = ArcadeEffects.satellite(modern: modern)
            node.position = point(saved.position)
            addChild(node)
            satellite = OrbitalTraffic(node: node,
                                       velocity: vector(saved.velocity),
                                       remaining: CGFloat(saved.remaining))
        }
        if let saved = snapshot.station {
            let node = ArcadeEffects.station(modern: modern, damage: stationDamage)
            node.setScale(1.08)
            node.position = point(saved.position)
            addChild(node)
            station = OrbitalTraffic(node: node,
                                     velocity: vector(saved.velocity),
                                     remaining: CGFloat(saved.remaining))
        }
        for saved in snapshot.shockwaves {
            let ring = ModernVisuals.shockRing(at: point(saved.center))
            addChild(ring)
            shockwaves.append(Shockwave(center: point(saved.center),
                                        elapsed: CGFloat(saved.elapsed),
                                        ring: ring, hit: [], maxRadius: 350))
        }
        if let saved = snapshot.blackHole {
            spawnBlackHole()
            blackHole?.node.position = point(saved.position)
            blackHole?.remaining = CGFloat(saved.remaining)
        }
        if let saved = snapshot.missile {
            let missile = SKShapeNode(ellipseOf: CGSize(width: 11, height: 19))
            missile.fillColor = modern ? ModernVisuals.fire : .black
            missile.strokeColor = modern ? .yellow : .white
            missile.position = point(saved.position)
            addChild(missile)
            nuclearMissile = NuclearMissile(
                node: missile, velocity: vector(saved.velocity),
                fuse: CGFloat(saved.remaining))
        }
        updateStyle()
        updateHud()
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
