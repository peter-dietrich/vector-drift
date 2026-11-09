import AppKit
import CoreGraphics
import SpriteKit
import simd

/// A quiet deep-space sky rendered from original procedural data.
///
/// Most stars live in one cached texture (rather than hundreds of live nodes).
/// Only the nebula veils and the dust belt move. A lightweight SpriteKit
/// fragment shader refracts the background around a black hole.
///
/// No telescope imagery or copyrighted astrophotography is bundled.
final class ModernSpaceBackdrop: SKNode {
    let sceneSize: CGSize

    private let stars: SKSpriteNode
    private let dust: SKSpriteNode
    private var nebulae: [SKSpriteNode] = []
    private let lensCenter = SKUniform(name: "u_lensCenter", vectorFloat2: vector_float2(0.5, 0.5))
    private let lensStrength = SKUniform(name: "u_lensStrength", float: 0)

    init(size: CGSize) {
        sceneSize = CGSize(width: max(1, size.width), height: max(1, size.height))
        stars = SKSpriteNode(texture: Self.starTexture(size: sceneSize), size: sceneSize)
        dust = SKSpriteNode(texture: Self.dustTexture(size: sceneSize), size: sceneSize)
        super.init()

        zPosition = -30
        isUserInteractionEnabled = false

        stars.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        stars.zPosition = -5

        // The image uses UV coordinates, so refraction shifts actual galaxies,
        // bright stars and faint stellar points near the lens center.
        let shader = SKShader(source: """
        void main() {
            vec2 uv = v_tex_coord;
            vec2 center = u_lensCenter;
            vec2 d = uv - center;
            float aspect = u_sprite_size.x / max(1.0, u_sprite_size.y);
            vec2 physical = vec2(d.x * aspect, d.y);
            float r = length(physical);
            float influence = (1.0 - smoothstep(0.035, 0.23, r)) *
                              smoothstep(0.013, 0.048, r);
            float warp = u_lensStrength * 0.027 * influence /
                         (0.40 + 7.0 * r);
            vec2 direction = physical / max(r, 0.0001);
            vec2 offset = vec2(direction.x / aspect, direction.y) * warp;
            vec2 sampled = clamp(uv + offset, 0.001, 0.999);
            vec4 imageColor = texture2D(u_texture, sampled);
            gl_FragColor = imageColor * v_color_mix;
        }
        """)
        shader.uniforms = [lensCenter, lensStrength]
        stars.shader = shader
        addChild(stars)

        let cloudTexture = Self.cloudTexture()
        for i in 0..<3 {
            let cloud = SKSpriteNode(texture: cloudTexture)
            cloud.size = CGSize(width: sceneSize.width * (i == 0 ? 0.63 : 0.52),
                                height: sceneSize.height * (i == 1 ? 0.83 : 0.67))
            cloud.position = CGPoint(
                x: sceneSize.width * [0.30, 0.71, 0.52][i],
                y: sceneSize.height * [0.63, 0.35, 0.76][i])
            cloud.zPosition = -4 + CGFloat(i) * 0.2
            cloud.zRotation = CGFloat(i) * 1.35
            cloud.color = [SKColor(calibratedRed: 0.34, green: 0.59, blue: 0.82, alpha: 1),
                           SKColor(calibratedRed: 0.51, green: 0.42, blue: 0.72, alpha: 1),
                           SKColor(calibratedRed: 0.31, green: 0.62, blue: 0.62, alpha: 1)][i]
            cloud.colorBlendFactor = 0.6
            cloud.blendMode = .add
            cloud.alpha = [0.16, 0.12, 0.09][i]
            addChild(cloud)
            nebulae.append(cloud)
            let motion: CGFloat = i.isMultiple(of: 2) ? 24 : -21
            let duration = 18.0 + Double(i) * 6.0
            cloud.run(.repeatForever(.group([
                .sequence([.moveBy(x: motion, y: motion * 0.29, duration: duration),
                           .moveBy(x: -motion, y: -motion * 0.29, duration: duration)]),
                .sequence([.scale(to: 1.10, duration: duration),
                           .scale(to: 0.94, duration: duration)]),
                .rotate(byAngle: (i.isMultiple(of: 2) ? 1 : -1) * 0.19,
                        duration: duration * 2)
            ])))
        }

        dust.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        dust.zPosition = -2
        dust.alpha = 0.05
        dust.blendMode = .add
        addChild(dust)
        dust.run(.repeatForever(.sequence([
            .moveBy(x: -18, y: 9, duration: 17),
            .moveBy(x: 18, y: -9, duration: 17)
        ])))
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func animate(time: CGFloat, density: CGFloat) {
        let amount = max(0, min(1, density))
        dust.alpha = 0.035 + amount * 0.24
        // Slow independent variation, preserving a dark and readable game area.
        for (i, cloud) in nebulae.enumerated() {
            let pulse = 0.85 + 0.15 * sin(time * (0.11 + CGFloat(i) * 0.025) + CGFloat(i) * 1.6)
            cloud.alpha = [0.16, 0.12, 0.09][i] * pulse
        }
    }

    func lens(at location: CGPoint?, intensity: CGFloat = 1) {
        guard let location else {
            lensStrength.floatValue = 0
            return
        }
        lensCenter.vectorFloat2Value = vector_float2(
            Float(location.x / sceneSize.width),
            Float(location.y / sceneSize.height))
        lensStrength.floatValue = Float(max(0, min(1, intensity)))
    }

    // MARK: - Original scene artwork

    private static func bitmap(size: CGSize) -> CGContext? {
        CGContext(data: nil,
                  width: max(1, Int(ceil(size.width))),
                  height: max(1, Int(ceil(size.height))),
                  bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    private static func texture(from ctx: CGContext?, fallback size: CGSize) -> SKTexture {
        guard let image = ctx?.makeImage() else {
            return SKTexture(image: NSImage(size: size))
        }
        let t = SKTexture(cgImage: image)
        t.filteringMode = .linear
        return t
    }

    private static func starTexture(size: CGSize) -> SKTexture {
        guard let ctx = bitmap(size: size) else { return texture(from: nil, fallback: size) }
        let w = size.width
        let h = size.height
        ctx.setFillColor(CGColor(red: 0.003, green: 0.007, blue: 0.023, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))

        // Faint Milky-Way-like dust lane made of very subtle diffuse patches.
        // Blobs are colored near-neutral and never reach bright-nebula opacity.
        for _ in 0..<105 {
            let x = CGFloat.random(in: -0.10...1.10) * w
            let bandY = (0.64 - 0.32 * (x / max(1, w))) * h
            let y = bandY + CGFloat.random(in: -0.13...0.13) * h
            let radius = CGFloat.random(in: 25...100)
            radial(ctx, at: CGPoint(x: x, y: y),
                   radius: radius,
                   color: CGColor(red: 0.10, green: 0.14, blue: 0.28, alpha: 0.026))
        }

        // A small number of distant, low-contrast galaxies, with different
        // inclinations and visible but restrained central light.
        for i in 0..<7 {
            let x = CGFloat.random(in: 0.09...0.91) * w
            let y = CGFloat.random(in: 0.12...0.88) * h
            let galaxySize = CGFloat.random(in: 12...34)
            galaxy(ctx, center: CGPoint(x: x, y: y), radius: galaxySize,
                   rotation: CGFloat.random(in: 0...(2 * .pi)),
                   flatness: i.isMultiple(of: 2) ? 0.27 : 0.62)
        }

        // Many low-contrast pinpoints, not a distracting white-noise screen.
        for _ in 0..<950 {
            let x = CGFloat.random(in: 0...w)
            let y = CGFloat.random(in: 0...h)
            let r = CGFloat.random(in: 0.26...0.88)
            let warm = Int.random(in: 0...7) == 0
            let alpha = CGFloat.random(in: 0.10...0.48)
            ctx.setFillColor(CGColor(red: warm ? 0.98 : 0.73, green: warm ? 0.83 : 0.86,
                                     blue: warm ? 0.68 : 1.0, alpha: alpha))
            ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }

        // 110 brighter stars plus a few recognizable starburst/diffraction
        // patterns. Approximate telescope-inspired visual language, not a
        // reproduction of any particular astronomical observation.
        for _ in 0..<110 {
            let p = CGPoint(x: CGFloat.random(in: 0...w),
                            y: CGFloat.random(in: 0...h))
            let r = CGFloat.random(in: 0.85...1.48)
            radial(ctx, at: p, radius: r * 4,
                   color: CGColor(red: 0.58, green: 0.77, blue: 1.0, alpha: 0.13))
            ctx.setFillColor(CGColor(red: 0.80, green: 0.90, blue: 1, alpha: 0.74))
            ctx.fillEllipse(in: CGRect(x: p.x-r, y: p.y-r, width: 2*r, height: 2*r))
        }

        let prominent: [(CGFloat, CGFloat, CGFloat)] = [
            (0.13, 0.81, 1.2), (0.36, 0.32, 0.9), (0.74, 0.67, 1.0),
            (0.88, 0.17, 1.25), (0.54, 0.89, 0.8), (0.24, 0.21, 0.9),
            (0.64, 0.46, 0.75), (0.91, 0.78, 0.8), (0.43, 0.62, 0.8)
        ]
        for (x, y, sizeFactor) in prominent {
            brightStar(ctx, center: CGPoint(x: x * w, y: y * h), scale: sizeFactor)
        }
        return texture(from: ctx, fallback: size)
    }

    private static func brightStar(_ ctx: CGContext, center: CGPoint, scale: CGFloat) {
        radial(ctx, at: center, radius: 13 * scale,
               color: CGColor(red: 0.68, green: 0.83, blue: 1, alpha: 0.30))
        ctx.setFillColor(CGColor(red: 0.93, green: 0.96, blue: 1, alpha: 0.94))
        let r = 1.8 * scale
        ctx.fillEllipse(in: CGRect(x: center.x-r, y: center.y-r, width: 2*r, height: 2*r))
        // Six restrained telescope-style diffraction rays.
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3
            let length = (i.isMultiple(of: 2) ? 13 : 8) * scale
            let end = CGPoint(x: center.x + cos(angle) * length,
                              y: center.y + sin(angle) * length)
            let path = CGMutablePath()
            path.move(to: center)
            path.addLine(to: end)
            ctx.addPath(path)
            ctx.setStrokeColor(CGColor(red: 0.77, green: 0.88, blue: 1, alpha: 0.23))
            ctx.setLineWidth(0.65)
            ctx.strokePath()
        }
    }

    private static func galaxy(_ ctx: CGContext, center: CGPoint, radius: CGFloat,
                               rotation: CGFloat, flatness: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: rotation)
        ctx.scaleBy(x: 1, y: flatness)
        for step in (1...14).reversed() {
            let r = radius * CGFloat(step) / 14
            let alpha = (15 - CGFloat(step)) / 14 * 0.012
            ctx.setFillColor(CGColor(red: 0.57, green: 0.64, blue: 0.81, alpha: alpha))
            ctx.fillEllipse(in: CGRect(x: -r, y: -r, width: 2*r, height: 2*r))
        }
        for _ in 0..<28 {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 0...radius)
            let r = CGFloat.random(in: 0.3...0.65)
            ctx.setFillColor(CGColor(red: 0.84, green: 0.86, blue: 1.0, alpha: 0.21))
            ctx.fillEllipse(in: CGRect(x: cos(angle)*distance, y: sin(angle)*distance,
                                       width: r, height: r))
        }
        ctx.restoreGState()
    }

    private static func radial(_ ctx: CGContext, at point: CGPoint, radius: CGFloat,
                               color: CGColor) {
        let clear = CGColor(red: color.components?[0] ?? 1,
                            green: color.components?[1] ?? 1,
                            blue: color.components?[2] ?? 1, alpha: 0)
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [color, clear] as CFArray,
                                        locations: [0, 1]) else { return }
        ctx.drawRadialGradient(gradient, startCenter: point, startRadius: 0,
                               endCenter: point, endRadius: radius,
                               options: [.drawsAfterEndLocation])
    }

    private static func cloudTexture() -> SKTexture {
        let size = CGSize(width: 400, height: 340)
        guard let ctx = bitmap(size: size) else { return texture(from: nil, fallback: size) }
        for i in 0..<145 {
            let x = CGFloat.random(in: 40...360)
            let track = 0.48 * x + 80
            let y = track + CGFloat.random(in: -60...60)
            let radius = CGFloat.random(in: 18...84)
            let warm = i.isMultiple(of: 5)
            radial(ctx, at: CGPoint(x: x, y: y), radius: radius,
                   color: CGColor(red: warm ? 0.62 : 0.28,
                                  green: warm ? 0.40 : 0.55,
                                  blue: 0.78, alpha: CGFloat.random(in: 0.025...0.075)))
        }
        return texture(from: ctx, fallback: size)
    }

    private static func dustTexture(size: CGSize) -> SKTexture {
        guard let ctx = bitmap(size: size) else { return texture(from: nil, fallback: size) }
        let w = size.width
        let h = size.height
        for _ in 0..<480 {
            let x = CGFloat.random(in: 0...w)
            let lane = h * (0.76 - 0.48 * x / max(w, 1))
            let y = lane + CGFloat.random(in: -0.14...0.14) * h
            let r = CGFloat.random(in: 0.3...1.1)
            ctx.setFillColor(CGColor(red: 0.55, green: 0.72, blue: 0.88,
                                     alpha: CGFloat.random(in: 0.12...0.36)))
            ctx.fillEllipse(in: CGRect(x: x-r, y: y-r, width: r*2, height: r*2))
        }
        return texture(from: ctx, fallback: size)
    }
}
