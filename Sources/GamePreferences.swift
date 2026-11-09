import Foundation
import SwiftUI

// User-editable arcade rules. Built-in difficulties are never mutated.
struct GameRules: Codable, Equatable {
    enum EdgeMode: String, Codable, CaseIterable, Identifiable {
        case wrap = "Wrap to opposite edge"
        case bounce = "Bounce off edges"
        var id: String { rawValue }
    }
    enum RockMix: String, Codable, CaseIterable, Identifiable {
        case mixed = "Mixed sizes"
        case largest = "Largest only"
        case swarm = "Small swarm"
        var id: String { rawValue }
    }

    var maxBullets: Int
    var bulletLifetime: Double
    var shotInterval: Double
    var shieldDuration: Double
    var shieldCooldown: Double
    var asteroidsPerWave: Int
    var waveGrowth: Int
    var largestRock: Int
    var largestRockHits: Int
    var asteroidSpeed: Double
    var startingLives: Int
    var edgeMode: EdgeMode
    var rockMix: RockMix
    var cometEnabled: Bool
    var saucerEnabled: Bool
    var blackHoleEnabled: Bool
    var missilesPerWave: Int

    static func defaults(for difficulty: String) -> GameRules {
        switch difficulty {
        case "easy":
            return GameRules(maxBullets: 6, bulletLifetime: 1.5, shotInterval: 0.13,
                             shieldDuration: 7, shieldCooldown: 5,
                             asteroidsPerWave: 3, waveGrowth: 1, largestRock: 3,
                             largestRockHits: 2, asteroidSpeed: 0.75, startingLives: 5,
                             edgeMode: .wrap, rockMix: .largest,
                             cometEnabled: true, saucerEnabled: true, blackHoleEnabled: true, missilesPerWave: 2)
        case "hard":
            return GameRules(maxBullets: 6, bulletLifetime: 0.55, shotInterval: 0.20,
                             shieldDuration: 3, shieldCooldown: 9,
                             asteroidsPerWave: 7, waveGrowth: 2, largestRock: 5,
                             largestRockHits: 3, asteroidSpeed: 1.32, startingLives: 2,
                             edgeMode: .wrap, rockMix: .mixed,
                             cometEnabled: true, saucerEnabled: true, blackHoleEnabled: true, missilesPerWave: 2)
        default:
            return GameRules(maxBullets: 6, bulletLifetime: 0.95, shotInterval: 0.16,
                             shieldDuration: 5, shieldCooldown: 7,
                             asteroidsPerWave: 4, waveGrowth: 1, largestRock: 4,
                             largestRockHits: 2, asteroidSpeed: 1.0, startingLives: 3,
                             edgeMode: .wrap, rockMix: .mixed,
                             cometEnabled: true, saucerEnabled: true, blackHoleEnabled: true, missilesPerWave: 2)
        }
    }

    func validated() -> GameRules {
        var r = self
        r.maxBullets = min(30, max(1, maxBullets))
        r.bulletLifetime = min(6, max(0.15, bulletLifetime))
        r.shotInterval = min(0.8, max(0.055, shotInterval))
        r.shieldDuration = min(30, max(1, shieldDuration))
        r.shieldCooldown = min(45, max(0, shieldCooldown))
        r.asteroidsPerWave = min(24, max(1, asteroidsPerWave))
        r.waveGrowth = min(5, max(0, waveGrowth))
        r.largestRock = min(5, max(1, largestRock))
        r.largestRockHits = min(6, max(1, largestRockHits))
        r.asteroidSpeed = min(3, max(0.2, asteroidSpeed))
        r.startingLives = min(15, max(1, startingLives))
        r.missilesPerWave = min(10, max(0, missilesPerWave))
        return r
    }

    func rockCount(wave: Int) -> Int {
        min(30, asteroidsPerWave + max(0, wave - 1) * waveGrowth)
    }

    func initialRockLevel(at index: Int) -> Int {
        let largest = largestRock
        switch rockMix {
        case .largest: return largest
        case .swarm: return max(1, largest - 2)
        case .mixed:
            return max(1, largest - (index % 3 == 0 ? 0 : index % 3 == 1 ? 1 : 2))
        }
    }

    func hits(level: Int, difficulty: String) -> Int {
        if level == largestRock { return largestRockHits }
        // Preserve hard-mode giant armor and default easy/medium fragments.
        if difficulty == "hard" && level == 4 && largestRock >= 5 { return 2 }
        return 1
    }
}

struct GamePreset: Codable, Identifiable {
    var id: String
    var name: String
    var rules: GameRules
}

// Coordinates use a portable Codable representation, independent of SpriteKit.
struct SavedVector: Codable {
    var x: Double
    var y: Double
}

struct SavedRock: Codable {
    var level: Int
    var position: SavedVector
    var velocity: SavedVector
    var rotation: Double
    var spin: Double
    var hitPoints: Int
    var remainingFracture: Double?
    var fractureDuration: Double
    var vertices: [SavedVector]
}

struct SavedProjectile: Codable {
    var position: SavedVector
    var velocity: SavedVector
    var remaining: Double
}

struct SavedMovingEnemy: Codable {
    var position: SavedVector
    var velocity: SavedVector
    var remaining: Double
}

struct SavedShockwave: Codable {
    var center: SavedVector
    var elapsed: Double
}

struct GameSnapshot: Codable {
    var version: Int
    var difficulty: String
    var modern: Bool
    var activePresetID: String
    var customRules: GameRules?
    var score: Int
    var lives: Int
    var wave: Int
    var elapsed: Double
    var heading: Double
    var shipPosition: SavedVector
    var shipVelocity: SavedVector
    var protectionRemaining: Double
    var shieldActive: Bool
    var shieldRemaining: Double
    var shieldCooldownRemaining: Double
    var timeSinceShot: Double
    var timeSinceWarp: Double
    var timeSinceComet: Double
    var nextCometDelay: Double
    var timeSinceSaucer: Double
    var nextSaucerDelay: Double
    var timeSinceSaucerShot: Double
    var rocks: [SavedRock]
    var bullets: [SavedProjectile]
    var enemyBullets: [SavedProjectile]
    var comet: SavedMovingEnemy?
    var saucer: SavedMovingEnemy?
    var shockwaves: [SavedShockwave]
    var blackHole: SavedMovingEnemy?
    var timeSinceBlackHole: Double
    var nextBlackHoleDelay: Double
    var missilesRemaining: Int
    var missile: SavedProjectile?
}

struct GameSaveSlot: Codable, Identifiable {
    var id: String
    var name: String
    var savedAt: Date
    var snapshot: GameSnapshot
}

enum GameStore {
    private static let presetsKey = "vectorDrift.customPresets.v1"
    private static let savesKey = "vectorDrift.savedGames.v1"

    private static func load<T: Decodable>(_ key: String) -> [T] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let objects = try? JSONDecoder().decode([T].self, from: data) else { return [] }
        return objects
    }

    private static func persist<T: Encodable>(_ values: [T], at key: String) {
        guard let bytes = try? JSONEncoder().encode(values) else { return }
        UserDefaults.standard.set(bytes, forKey: key)
    }

    static func presets() -> [GamePreset] { load(presetsKey) }

    static func preset(id: String) -> GamePreset? {
        presets().first(where: { $0.id == id })
    }

    static func savePreset(_ preset: GamePreset) {
        var list = presets()
        let validated = GamePreset(id: preset.id, name: preset.name,
                                   rules: preset.rules.validated())
        if let index = list.firstIndex(where: { $0.id == preset.id }) {
            list[index] = validated
        } else {
            list.append(validated)
        }
        persist(list, at: presetsKey)
    }

    static func deletePreset(id: String) {
        persist(presets().filter { $0.id != id }, at: presetsKey)
    }

    static func saves() -> [GameSaveSlot] { load(savesKey) }

    static func saveGame(_ snapshot: GameSnapshot) -> GameSaveSlot {
        let slot = GameSaveSlot(
            id: UUID().uuidString,
            name: "Wave \(snapshot.wave) · \(snapshot.customRules == nil ? snapshot.difficulty.capitalized : "Custom") · \(snapshot.score) points",
            savedAt: Date(), snapshot: snapshot
        )
        var list = saves()
        list.insert(slot, at: 0)
        persist(Array(list.prefix(12)), at: savesKey)
        return slot
    }

    static func deleteGame(id: String) {
        persist(saves().filter { $0.id != id }, at: savesKey)
    }
}

struct GamePresetEditor: View {
    let baseDifficulty: String
    let activePresetID: String
    let apply: (GamePreset?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var allPresets: [GamePreset] = []
    @State private var selectedID = ""
    @State private var presetName = "My Arcade"
    @State private var rules = GameRules.defaults(for: "medium")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CUSTOM GAME").font(.system(.title2, design: .monospaced).bold())
            Text("Build your own rules, save named presets and apply one to a new game.")
                .font(.callout).foregroundStyle(.secondary)

            HStack {
                Picker("Saved preset", selection: $selectedID) {
                    Text("New preset").tag("")
                    ForEach(allPresets) { item in Text(item.name).tag(item.id) }
                }
                .onChange(of: selectedID) { id in
                    if let preset = allPresets.first(where: { $0.id == id }) {
                        presetName = preset.name
                        rules = preset.rules
                    }
                }
                Button("New") {
                    selectedID = ""
                    presetName = "My Arcade"
                    rules = GameRules.defaults(for: baseDifficulty)
                }
            }
            TextField("Preset name", text: $presetName)

            Form {
                Section("Weapons") {
                    Stepper("Maximum bullets on screen: \(rules.maxBullets)",
                            value: $rules.maxBullets, in: 1...30)
                    HStack {
                        Text("Bullet lifetime")
                        Slider(value: $rules.bulletLifetime, in: 0.15...6, step: 0.05)
                        Text(String(format: "%.2f s", rules.bulletLifetime))
                            .monospacedDigit().frame(width: 65)
                    }
                    HStack {
                        Text("Time between shots")
                        Slider(value: $rules.shotInterval, in: 0.06...0.8, step: 0.02)
                        Text(String(format: "%.2f s", rules.shotInterval))
                            .monospacedDigit().frame(width: 65)
                    }
                }
                Section("Shields") {
                    HStack {
                        Text("Shield duration")
                        Slider(value: $rules.shieldDuration, in: 1...30, step: 1)
                        Text("\(Int(rules.shieldDuration)) s").frame(width: 50)
                    }
                    HStack {
                        Text("Recharge time")
                        Slider(value: $rules.shieldCooldown, in: 0...45, step: 1)
                        Text("\(Int(rules.shieldCooldown)) s").frame(width: 50)
                    }
                }
                Section("Asteroids") {
                    Stepper("Starting rocks: \(rules.asteroidsPerWave)",
                            value: $rules.asteroidsPerWave, in: 1...24)
                    Stepper("Additional rocks per wave: \(rules.waveGrowth)",
                            value: $rules.waveGrowth, in: 0...5)
                    Picker("Largest asteroid", selection: $rules.largestRock) {
                        Text("Small").tag(1)
                        Text("Medium").tag(2)
                        Text("Large").tag(3)
                        Text("Giant").tag(4)
                        Text("Titan").tag(5)
                    }
                    Picker("Starting types", selection: $rules.rockMix) {
                        ForEach(GameRules.RockMix.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Stepper("Shots for largest rock: \(rules.largestRockHits)",
                            value: $rules.largestRockHits, in: 1...6)
                    HStack {
                        Text("Rock speed")
                        Slider(value: $rules.asteroidSpeed, in: 0.2...3, step: 0.1)
                        Text(String(format: "%.1f×", rules.asteroidSpeed))
                            .frame(width: 54)
                    }
                }
                Section("World and enemies") {
                    Picker("Screen edges", selection: $rules.edgeMode) {
                        ForEach(GameRules.EdgeMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Stepper("Starting lives: \(rules.startingLives)",
                            value: $rules.startingLives, in: 1...15)
                    Toggle("Enable comets", isOn: $rules.cometEnabled)
                    Toggle("Enable UFO saucers", isOn: $rules.saucerEnabled)
                    Toggle("Enable black holes", isOn: $rules.blackHoleEnabled)
                    Stepper("Thermonuclear missiles per wave: \(rules.missilesPerWave)", value: $rules.missilesPerWave, in: 0...10)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Delete preset", role: .destructive) {
                    guard !selectedID.isEmpty else { return }
                    let removedID = selectedID
                    GameStore.deletePreset(id: removedID)
                    allPresets = GameStore.presets()
                    selectedID = ""
                    if activePresetID == removedID { apply(nil) }
                }
                .disabled(selectedID.isEmpty)
                Spacer()
                Button("Use built-in difficulty") {
                    apply(nil)
                    dismiss()
                }
                Button("Save & Start Custom Game") {
                    let preset = GamePreset(
                        id: selectedID.isEmpty ? UUID().uuidString : selectedID,
                        name: presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "My Arcade" : presetName.trimmingCharacters(in: .whitespacesAndNewlines),
                        rules: rules.validated()
                    )
                    GameStore.savePreset(preset)
                    apply(preset)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 660, height: 740)
        .onAppear {
            allPresets = GameStore.presets()
            if let existing = GameStore.preset(id: activePresetID) {
                selectedID = existing.id
                presetName = existing.name
                rules = existing.rules
            } else {
                rules = GameRules.defaults(for: baseDifficulty)
            }
        }
    }
}
