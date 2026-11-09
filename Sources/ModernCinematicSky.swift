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
            case .cosmicCliffs: return "webb-cosmic-cliffs-4k-v1.png"
            case .orionNebula: return "hubble-orion-nebula-v1.jpg"
            }
        }

        var sourceURL: URL {
            let value: String
            switch self {
            case .cosmicCliffs:
                value = "https://svs.gsfc.nasa.gov/vis/a030000/a031200/a031285/eta-carina-cliffs-webb-STScI-01G8GX1KMWX2XA4PK2EWM7KE3R-hw_resolution.png"
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
        request.timeoutInterval = 28
        request.cachePolicy = .returnCacheDataElseLoad
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let data,
                  data.count > 15_000,
                  data.count < 18_000_000,
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
    private(set) var sceneSize: CGSize

    // One screen-filling sprite, not multiple independently visible photos.
    // A single fragment shader blends both photographs through a continuously
    // evolving, feathered gas field; therefore no photo rectangles can appear.
    private let fallback: ModernSpaceBackdrop
    private var canvas: SKSpriteNode?
    private var webImage: SKTexture?
    private var orionImage: SKTexture?
    private var cloudUniform: SKUniform?
    private var shader: SKShader?

    private let timeUniform = SKUniform(name: "u_time", float: 0)
    private let velocityUniform = SKUniform(name: "u_movement", vectorFloat2: vector_float2(0, 0))
    private let cropWebb = SKUniform(name: "u_webbCrop", vectorFloat2: vector_float2(0.82, 0.82))
    private let cropOrion = SKUniform(name: "u_orionCrop", vectorFloat2: vector_float2(0.82, 0.82))
    private let overlayUniform = SKUniform(name: "u_overlayBlend", float: 0)
    private let densityUniform = SKUniform(name: "u_density", float: 0.5)
    private let warpUniform = SKUniform(name: "u_warp", float: 0)
    private let lensCenterUniform = SKUniform(name: "u_lensCenter", vectorFloat2: vector_float2(0.5, 0.5))
    private let lensStrengthUniform = SKUniform(name: "u_lensStrength", float: 0)
    private let aspectUniform = SKUniform(name: "u_aspect", float: 1.5)

    private var previousTime: CGFloat?
    private var movement = CGVector.zero
    private var warpRemaining: CGFloat = 0
    private var overlayAppearance: CGFloat = 0
    private var currentLensPoint: CGPoint?
    private var currentLensIntensity: CGFloat = 0

    init(size: CGSize) {
        sceneSize = CGSize(width: max(1, size.width), height: max(1, size.height))
        fallback = ModernSpaceBackdrop(size: sceneSize)
        super.init()
        zPosition = -30
        isUserInteractionEnabled = false

        fallback.zPosition = -20
        addChild(fallback)
        resize(to: sceneSize)

        // NASA textures download once per device and are cached. The existing
        // procedural sky is a usable fallback for first run and offline play.
        TelescopeSkyLibrary.image(.cosmicCliffs) { [weak self] picture in
            guard let self, let picture else { return }
            let texture = SKTexture(image: picture)
            texture.filteringMode = .linear
            self.webImage = texture
            self.configureCanvas()
        }
        TelescopeSkyLibrary.image(.orionNebula) { [weak self] picture in
            guard let self, let picture else { return }
            let texture = SKTexture(image: picture)
            texture.filteringMode = .linear
            self.orionImage = texture
            self.configureCanvas()
        }
    }

    required init?(coder: NSCoder) { nil }

    func resize(to size: CGSize) {
        let previous = sceneSize
        sceneSize = CGSize(width: max(1, size.width), height: max(1, size.height))
        fallback.xScale = sceneSize.width / max(1, previous.width) * fallback.xScale
        fallback.yScale = sceneSize.height / max(1, previous.height) * fallback.yScale
        canvas?.size = sceneSize
        canvas?.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        aspectUniform.floatValue = Float(sceneSize.width / sceneSize.height)
        updateTextureCrops()
        applyLensCoordinates()
    }

    private func configureCanvas() {
        guard let webb = webImage else { return }

        if canvas == nil {
            let sprite = SKSpriteNode(texture: webb, size: sceneSize)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            sprite.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
            sprite.alpha = 0
            sprite.zPosition = -10
            sprite.blendMode = .alpha
            addChild(sprite)
            canvas = sprite

            // The second sampler must start with a real texture even when
            // the Orion download has not yet succeeded.
            let overlay = SKUniform(name: "u_cloudPhoto", texture: orionImage ?? webb)
            cloudUniform = overlay
            let shader = SKShader(source: Self.compositeShader)
            shader.uniforms = [
                timeUniform, velocityUniform,
                cropWebb, cropOrion, overlay, overlayUniform,
                densityUniform, warpUniform,
                lensCenterUniform, lensStrengthUniform, aspectUniform
            ]
            sprite.shader = shader
            self.shader = shader

            // Fade the whole new sky in over the procedural fallback.
            sprite.run(.fadeAlpha(to: 1, duration: 2.2))
            fallback.run(.fadeAlpha(to: 0.10, duration: 2.8))
        }
        cloudUniform?.textureValue = orionImage ?? webb
        if orionImage != nil {
            // A later fade-in makes the appearance stable during async loading.
            overlayAppearance = 0
        }
        updateTextureCrops()
    }

    private func updateTextureCrops() {
        if let webImage { cropWebb.vectorFloat2Value = crop(for: webImage) }
        if let orionImage { cropOrion.vectorFloat2Value = crop(for: orionImage) }
        else if let webImage { cropOrion.vectorFloat2Value = crop(for: webImage) }
    }

    /// Aspect-fill, then a permanent 18% overscan for UV displacement. We do
    /// not rotate, translate or scale the image node outside the playfield.
    private func crop(for texture: SKTexture) -> vector_float2 {
        let textureSize = texture.size()
        let imageRatio = textureSize.width / max(1, textureSize.height)
        let viewRatio = sceneSize.width / max(1, sceneSize.height)
        let overscan: CGFloat = 0.77
        if imageRatio > viewRatio {
            return vector_float2(Float(overscan * viewRatio / imageRatio),
                                 Float(overscan))
        } else {
            return vector_float2(Float(overscan),
                                 Float(overscan * imageRatio / viewRatio))
        }
    }

    /// A coherent flow field displaces *pixels inside a stationary, full-screen
    /// image*. Cloud masks are smooth, changing and irregular—not rectangles.
    /// This is a single compositing pass using two samples of NASA photography.
    private static let compositeShader: String = """
    float noise2(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
        float b = fract(sin(dot(i + vec2(1., 0.), vec2(127.1, 311.7))) * 43758.5453);
        float c = fract(sin(dot(i + vec2(0., 1.), vec2(127.1, 311.7))) * 43758.5453);
        float d = fract(sin(dot(i + vec2(1., 1.), vec2(127.1, 311.7))) * 43758.5453);
        return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
    }

    void main() {
        vec2 uv = v_tex_coord;
        float t = u_time;
        vec2 screenCenter = uv - vec2(0.5);
        float velocityScale = min(1.0, length(u_movement) * 6.0);

        // Large rolling gas eddies + finer turbulent curls. No sprite edges.
        vec2 advect = vec2(
            sin(uv.y * 10.5 + t * 0.17) * 0.011 +
            sin(uv.x * 7.2 - uv.y * 5.0 + t * 0.12) * 0.007,
            cos(uv.x * 8.5 - t * 0.15) * 0.011 +
            sin(uv.y * 9.4 + uv.x * 3.4 + t * 0.10) * 0.007
        );

        // A warped starfield is convincing only when there is stellar detail
        // to distort. In screen UV, the hole occupies a circular world-space
        // region even on an ultra-wide game window.
        vec2 fromHole = uv - u_lensCenter;
        vec2 metric = vec2(fromHole.x * u_aspect, fromHole.y);
        float distanceToHole = length(metric);
        float annulus = smoothstep(0.015, 0.043, distanceToHole) *
                        (1.0 - smoothstep(0.17, 0.29, distanceToHole));
        vec2 bendDirection = metric / max(0.001, distanceToHole);
        vec2 bending = vec2(bendDirection.x / u_aspect,
                            bendDirection.y) *
                       (u_lensStrength * 0.028 * annulus /
                        (0.52 + distanceToHole * 7.0));

        // Actual photo pixels move, scale and reform through shader UVs.
        float push = u_warp * (0.085 + velocityScale * 0.025);
        vec2 zoomed = screenCenter * (1.0 - push) + 0.5;
        vec2 starUV = (zoomed - 0.5) * u_webbCrop + 0.5 +
                      u_movement * 0.22 + advect * 0.37 + bending;
        vec3 stars = texture2D(u_texture,
                               clamp(starUV, 0.003, 0.997)).rgb;

        // A second telescope image becomes an irregular translucent nebula.
        // Its photo boundaries never exist in scene geometry.
        vec2 fieldPoint = uv * 3.35 + vec2(t * 0.015, -t * 0.011);
        float broadCloud = noise2(fieldPoint + advect * 3.2);
        float fineCloud = noise2(uv * 8.7 - vec2(t * 0.035, -t * 0.026));
        float gas = broadCloud * 0.70 + fineCloud * 0.30;
        gas += 0.10 * sin(uv.x * 5.1 + uv.y * 6.3 + t * 0.07);
        float cloudMask = smoothstep(0.38, 0.72, gas);

        vec2 gasUV = (zoomed - 0.5) * u_orionCrop + 0.5 +
                     u_movement * 0.80 + advect * 1.30 + bending;
        vec3 cloudPhoto = texture2D(u_cloudPhoto,
                                    clamp(gasUV, 0.003, 0.997)).rgb;
        float cloudBlend = u_overlayBlend * cloudMask *
                           (0.80 + 0.20 * u_density);
        vec3 color = mix(stars, cloudPhoto, cloudBlend);

        // Filament-like emission gives the impression of gas moving through
        // space rather than a crossfading still photograph.
        float strands = smoothstep(0.44, 0.75,
                           fineCloud * 0.55 + broadCloud * 0.45);
        vec3 lightColor = mix(vec3(0.12, 0.34, 0.56),
                              vec3(0.66, 0.24, 0.13), broadCloud);
        color += lightColor * strands * cloudMask *
                 u_overlayBlend * 0.12;

        // Warp subtly stretches the stars and dust during hyperspace.
        if (u_warp > 0.005) {
            vec2 radial = normalize(screenCenter + vec2(0.0001));
            vec2 trailUV = clamp(starUV - radial * 0.028 * u_warp,
                                 0.003, 0.997);
            vec3 trail = texture2D(u_texture, trailUV).rgb;
            color = mix(color, max(color, trail * 0.90), u_warp * 0.45);
        }

        // Visual depth and legibility. The game remains readable even when
        // Cosmic Cliffs are intensely illuminated in the source photograph.
        float edge = length(screenCenter * vec2(u_aspect * 0.72, 1.0));
        float vignette = 1.0 - 0.18 * smoothstep(0.32, 0.80, edge);
        color *= vignette * 0.82;
        gl_FragColor = vec4(color, 1.0) * v_color_mix;
    }
    """

    /// Motion is fed into shader coordinates, not into moving rectangles.
    func animate(time: CGFloat, density: CGFloat, shipVelocity: CGVector,
                 thrusting: Bool) {
        fallback.animate(time: time, density: density)
        let dt = min(CGFloat(1.0 / 20.0), max(0, time - (previousTime ?? time)))
        previousTime = time
        warpRemaining = max(0, warpRemaining - dt)

        let acceleration: CGFloat = thrusting ? 0.013 : 0.006
        movement.dx = max(-0.16, min(0.16,
            movement.dx * 0.995 - shipVelocity.dx * dt * acceleration))
        movement.dy = max(-0.12, min(0.12,
            movement.dy * 0.995 - shipVelocity.dy * dt * acceleration))

        timeUniform.floatValue = Float(time)
        velocityUniform.vectorFloat2Value = vector_float2(
            Float(movement.dx / max(1, sceneSize.width)),
            Float(movement.dy / max(1, sceneSize.height)))
        densityUniform.floatValue = Float(max(0, min(1, density)))
        warpUniform.floatValue = Float(min(1, warpRemaining / 0.9))

        if orionImage != nil && canvas != nil {
            overlayAppearance = min(1, overlayAppearance + dt / 4)
            overlayUniform.floatValue = Float(overlayAppearance * 0.67)
        }
    }

    func lens(at point: CGPoint?, intensity: CGFloat = 1) {
        currentLensPoint = point
        currentLensIntensity = max(0, min(1, intensity))
        fallback.lens(at: point, intensity: intensity)
        applyLensCoordinates()
    }

    private func applyLensCoordinates() {
        guard let point = currentLensPoint else {
            lensStrengthUniform.floatValue = 0
            return
        }
        lensCenterUniform.vectorFloat2Value = vector_float2(
            Float(point.x / sceneSize.width), Float(point.y / sceneSize.height))
        lensStrengthUniform.floatValue = Float(currentLensIntensity)
    }

    func warpBurst() {
        warpRemaining = 0.9
    }
}
