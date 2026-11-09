import AppKit
import Foundation
import SpriteKit
import simd

/// Telescope photography credited to the original science teams.
///
/// Images download once over HTTPS, then live in the user's macOS Caches
/// directory for offline gameplay. There are no embedded third-party binaries,
/// and the older procedural background remains available while offline or
/// until the first download completes.
enum TelescopeSkyLibrary {
    enum Plate: Int, CaseIterable {
        case cosmicCliffs, orionNebula

        var cacheName: String {
            switch self {
            case .cosmicCliffs: return "webb-cosmic-cliffs-v1.jpg"
            case .orionNebula: return "hubble-orion-nebula-v1.jpg"
            }
        }

        var sourceURL: URL {
            let value: String
            switch self {
            case .cosmicCliffs:
                value = "https://svs.gsfc.nasa.gov/vis/a030000/a031200/a031285/eta-carina-cliffs-webb-STScI-01G8GX1KMWX2XA4PK2EWM7KE3R-hw_resolution_print.jpg"
            case .orionNebula:
                value = "https://svs.gsfc.nasa.gov/vis/a010000/a012000/a012086/c-1280.jpg"
            }
            return URL(string: value)!
        }
    }

    static let credit = "Images: NASA, ESA, CSA, STScI; Orion: NASA/ESA/STScI/AURA/The Hubble Heritage Team"
    static let sourcePages = [
        "https://svs.gsfc.nasa.gov/31285/",
        "https://svs.gsfc.nasa.gov/12086/"
    ]

    private static var cacheDirectory: URL? {
        guard let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = root.appendingPathComponent("VectorDrift/TelescopeSky", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// All completions run on the main queue because callers create SKTextures.
    static func image(_ plate: Plate, completion: @escaping (NSImage?) -> Void) {
        let localFile = cacheDirectory?.appendingPathComponent(plate.cacheName)
        if let localFile,
           let data = try? Data(contentsOf: localFile),
           let image = NSImage(data: data) {
            DispatchQueue.main.async { completion(image) }
            return
        }

        var request = URLRequest(url: plate.sourceURL)
        request.timeoutInterval = 16
        request.cachePolicy = .returnCacheDataElseLoad
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let data,
                  data.count > 15_000,
                  data.count < 8_000_000,
                  let image = NSImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            if let localFile { try? data.write(to: localFile, options: .atomic) }
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }
}

/// Raster image-based sky for Modern mode only; Classic stays unchanged.
///
/// A cached Webb image forms the far sky; an Orion image becomes a slow-moving
/// nebula veil; a second cropped Webb exposure adds different cloud motion.
/// Independent parallax, changing opacity, animated UV displacement and a
/// one-second warp impulse create travel/morphing without washing out gameplay.
final class ModernCinematicSky: SKNode {
    let sceneSize: CGSize

    private struct Layer {
        var node: SKSpriteNode
        let shader: SKShader
        let time: SKUniform
        let shift: SKUniform
        let lensCenter: SKUniform
        let lensStrength: SKUniform
        let morph: SKUniform
        let warp: SKUniform
        let baseAlpha: CGFloat
    }

    private let fallback: ModernSpaceBackdrop
    private var photos: [Layer] = []
    private var loaded = Set<TelescopeSkyLibrary.Plate>()
    private var lastTime: CGFloat?
    private var travel = CGVector.zero
    private var warpRemaining: CGFloat = 0

    init(size: CGSize) {
        sceneSize = CGSize(width: max(1, size.width), height: max(1, size.height))
        fallback = ModernSpaceBackdrop(size: size)
        super.init()
        zPosition = -30
        isUserInteractionEnabled = false

        fallback.zPosition = -20
        addChild(fallback)

        // Three separate image layers whose textures arrive asynchronously.
        photos = [
            makeLayer(depth: -10, baseAlpha: 0.82, morphAmount: 0.0013),
            makeLayer(depth: -9, baseAlpha: 0.34, morphAmount: 0.006),
            makeLayer(depth: -8, baseAlpha: 0.17, morphAmount: 0.008)
        ]

        TelescopeSkyLibrary.image(.cosmicCliffs) { [weak self] image in
            self?.install(image, plate: .cosmicCliffs)
        }
        TelescopeSkyLibrary.image(.orionNebula) { [weak self] image in
            self?.install(image, plate: .orionNebula)
        }
    }

    required init?(coder: NSCoder) { nil }

    /// Every layer has its own lens center because photo sprites have different
    /// sizes and positions; their UV coordinates are not the screen coordinates.
    private func makeLayer(depth: CGFloat, baseAlpha: CGFloat,
                           morphAmount: Float) -> Layer {
        let time = SKUniform(name: "u_time", float: 0)
        let shift = SKUniform(name: "u_shift", vectorFloat2: vector_float2(0, 0))
        let center = SKUniform(name: "u_lensCenter", vectorFloat2: vector_float2(0.5, 0.5))
        let lensStrength = SKUniform(name: "u_lensStrength", float: 0)
        let morph = SKUniform(name: "u_morph", float: morphAmount)
        let warp = SKUniform(name: "u_warp", float: 0)

        let shader = SKShader(source: """
            void main() {
                vec2 uv = v_tex_coord;
                float t = u_time;

                // Very small fluid displacement; no destructive re-sampling.
                vec2 flow = vec2(
                    sin(uv.y * 11.4 + t * 0.19) * 0.7 +
                    sin(uv.x * 16.3 - uv.y * 6.0 + t * 0.13) * 0.3,
                    cos(uv.x * 9.1 - t * 0.17) * 0.6 +
                    sin(uv.y * 12.8 + uv.x * 4.3 + t * 0.11) * 0.4
                );
                uv += flow * u_morph;

                // Warp acceleration zooms the picture slightly outward.
                uv = (uv - 0.5) * (1.0 - u_warp * 0.085) + 0.5;
                uv += u_shift;

                // Gravitational lensing refracts image detail around a dark core.
                vec2 r = uv - u_lensCenter;
                float d = length(r);
                float annulus = smoothstep(0.018, 0.046, d) *
                                (1.0 - smoothstep(0.12, 0.26, d));
                vec2 deflection = r / max(d, 0.001) *
                                  (0.019 * u_lensStrength * annulus /
                                   (0.42 + d * 9.0));
                vec2 sampleUV = clamp(uv + deflection, 0.002, 0.998);
                vec4 tex = texture2D(u_texture, sampleUV);
                gl_FragColor = tex * v_color_mix;
            }
            """)
        shader.uniforms = [time, shift, center, lensStrength, morph, warp]
        let node = SKSpriteNode(color: .clear, size: sceneSize)
        node.position = CGPoint(x: sceneSize.width * 0.5, y: sceneSize.height * 0.5)
        node.zPosition = depth
        node.alpha = 0
        node.shader = shader
        if depth > -10 { node.blendMode = .screen }
        addChild(node)

        return Layer(node: node, shader: shader, time: time,
                     shift: shift, lensCenter: center,
                     lensStrength: lensStrength, morph: morph,
                     warp: warp, baseAlpha: baseAlpha)
    }

    private func install(_ image: NSImage?, plate: TelescopeSkyLibrary.Plate) {
        guard let image else { return }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        loaded.insert(plate)
        if plate == .cosmicCliffs {
            photos[0].node.texture = texture
            photos[2].node.texture = texture
            // Oversized crop avoids visible image edges during thrust/zoom.
            photos[0].node.size = coverSize(for: texture, overfill: 1.31)
            photos[2].node.size = coverSize(for: texture, overfill: 1.57)
            photos[2].node.zRotation = -0.24
            photos[0].node.run(.fadeAlpha(to: 0.82, duration: 2))
            photos[2].node.run(.fadeAlpha(to: 0.17, duration: 3.5))
        } else {
            photos[1].node.texture = texture
            photos[1].node.size = coverSize(for: texture, overfill: 1.46)
            photos[1].node.zRotation = 0.11
            photos[1].node.run(.fadeAlpha(to: 0.34, duration: 3.5))
        }
        // Keep a touch of distant procedural starlight if Orion loads first;
        // the full procedural sky fades once the Webb image is present.
        if loaded.contains(.cosmicCliffs) {
            fallback.run(.fadeAlpha(to: 0.045, duration: 2.4))
        }
    }

    private func coverSize(for texture: SKTexture, overfill: CGFloat) -> CGSize {
        let pixels = texture.size()
        let ratio = max(sceneSize.width / max(1, pixels.width),
                        sceneSize.height / max(1, pixels.height))
        return CGSize(width: pixels.width * ratio * overfill,
                      height: pixels.height * ratio * overfill)
    }

    /// Invoked once per game frame. Motion is based on the ship, not a moving
    /// camera; 2D gameplay coordinate systems and collision logic do not change.
    func animate(time: CGFloat, density: CGFloat,
                 shipVelocity: CGVector, thrusting: Bool) {
        fallback.animate(time: time, density: density)
        let dt = min(1.0 / 20.0, max(0, time - (lastTime ?? time)))
        lastTime = time
        if warpRemaining > 0 { warpRemaining = max(0, warpRemaining - dt) }
        let speed = min(1, hypot(shipVelocity.dx, shipVelocity.dy) / 310)

        // Accumulated parallax is deliberately bounded. Individual plates use
        // independent scale factors; the nearest haze reacts most to thrust.
        let flightFactor: CGFloat = thrusting ? 0.012 : 0.005
        travel.dx = max(-32, min(32, travel.dx * 0.996 - shipVelocity.dx * dt * flightFactor))
        travel.dy = max(-24, min(24, travel.dy * 0.996 - shipVelocity.dy * dt * flightFactor))

        for i in photos.indices {
            guard photos[i].node.texture != nil else { continue }
            let layer = photos[i]
            let phase = CGFloat(i) * 1.64
            let perspective: CGFloat = [0.28, 0.80, 1.25][i]
            let slowX = sin(time * (0.045 + CGFloat(i) * 0.012) + phase) * 12
            let slowY = cos(time * (0.032 + CGFloat(i) * 0.014) + phase) * 10
            layer.node.position = CGPoint(
                x: sceneSize.width / 2 + slowX + travel.dx * perspective,
                y: sceneSize.height / 2 + slowY + travel.dy * perspective
            )
            layer.node.alpha = layer.baseAlpha *
                (0.92 + 0.08 * sin(time * 0.14 + phase)) *
                (i == 1 ? 0.80 + density * 0.23 : 1.0)
            layer.time.floatValue = Float(time)
            layer.shift.vectorFloat2Value = vector_float2(
                Float(sin(time * 0.055 + phase) * 0.006),
                Float(cos(time * 0.041 - phase) * 0.005)
            )
            layer.warp.floatValue = Float(warpRemaining * (0.75 + speed * 0.25))
        }
    }

    func lens(at point: CGPoint?, intensity: CGFloat = 1) {
        // Keep the existing lens available until photograph downloads finish.
        fallback.lens(at: point, intensity: intensity)
        for layer in photos {
            guard let point else {
                layer.lensStrength.floatValue = 0
                continue
            }
            let node = layer.node
            let origin = CGPoint(x: node.position.x - node.size.width / 2,
                                 y: node.position.y - node.size.height / 2)
            layer.lensCenter.vectorFloat2Value = vector_float2(
                Float((point.x - origin.x) / max(1, node.size.width)),
                Float((point.y - origin.y) / max(1, node.size.height))
            )
            layer.lensStrength.floatValue = Float(max(0, min(1, intensity)))
        }
    }

    /// A noticeable, short-lived photo zoom when the player hyperspace-jumps.
    func warpBurst() {
        warpRemaining = 1
    }
}
