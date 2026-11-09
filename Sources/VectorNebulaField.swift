import AppKit
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import SpriteKit
import simd

/// Original procedural, *vector-authored* nebula for Modern mode.
///
/// Bezier gas contours, tapered filaments, clusters and diffraction stars are
/// rendered once into low-cost textures. GPU shaders then animate each depth
/// separately and lens ALL layers around a black hole. No photographs, remote
/// content or image panels are used.
final class VectorNebulaField: SKNode {
    private struct AnimatedLayer {
        let tiles: [SKSpriteNode]
        let lensCenters: [SKUniform]
        let gridOffsets: [CGPoint]
        let tiled: Bool
        let time: SKUniform
        let drift: SKUniform
        let lens: SKUniform
        let morph: SKUniform
        let warp: SKUniform
        let aspect: SKUniform
        let direction: SKUniform
        let streak: SKUniform
        let perspective: CGFloat
        let baseOpacity: CGFloat
        let phase: CGFloat
    }

    private(set) var sceneSize: CGSize
    private var layers: [AnimatedLayer] = []
    private var backdropGroup: SKNode?
    private var sceneGeneration = 0
    private var lastTime: CGFloat?
    /// Integrated ship travel in world points. Unlike an eased offset, this
    /// keeps accumulating while the ship is coasting, so depth is observable.
    private var travel = CGVector.zero
    private var warpEnergy: CGFloat = 0
    private var lensLocation: CGPoint?
    private var lensIntensity: CGFloat = 0
    private var currentDensity: CGFloat = 0.5

    init(size: CGSize) {
        sceneSize = CGSize(width: max(1, size.width), height: max(1, size.height))
        super.init()
        zPosition = -30
        isUserInteractionEnabled = false
        createLayers()
    }

    required init?(coder: NSCoder) { nil }

    func resize(to size: CGSize) {
        sceneSize = CGSize(width: max(1, size.width), height: max(1, size.height))
        for layer in layers {
            let multiplier: CGFloat = layer.tiled ? 1 : 1.52
            for tile in layer.tiles {
                tile.size = CGSize(width: sceneSize.width * multiplier,
                                   height: sceneSize.height * multiplier)
            }
            layer.aspect.floatValue = Float(sceneSize.width / sceneSize.height)
        }
        positionLayers()
        updateLens()
    }

    /// Build a new, genuinely random cloud bank and stellar population for
    /// each wave. Crossfading preserves the sense of traversing space.
    func regenerate() {
        createLayers(transition: true)
    }

    func warpBurst() {
        warpEnergy = 1
    }

    /// Ship velocity supplies perspective, while each independent time/phase
    /// uniform bends gas within its own contour. No rectangular image motion.
    func animate(time: CGFloat, density: CGFloat,
                 shipVelocity: CGVector, thrusting: Bool) {
        let dt = min(0.05, max(0, time - (lastTime ?? time)))
        lastTime = time
        warpEnergy = max(0, warpEnergy - dt * 1.1)
        currentDensity = max(0, min(1, density))

        // Crucial: move SpriteKit geometry using real traveled distance,
        // not a few pixels of shader UV shift. Moving while coasting works too.
        travel.dx -= shipVelocity.dx * dt * 0.95
        travel.dy -= shipVelocity.dy * dt * 0.95
        positionLayers()

        let speed = hypot(shipVelocity.dx, shipVelocity.dy)
        let speedRatio = min(1, speed / 330)
        let normX = speed > 1 ? shipVelocity.dx / speed : 0
        let normY = speed > 1 ? shipVelocity.dy / speed : 0

        for (index, layer) in layers.enumerated() {
            let phase = layer.phase
            layer.time.floatValue = Float(time * (0.68 + CGFloat(index) * 0.07) + phase)
            layer.drift.vectorFloat2Value = vector_float2(0, 0)
            layer.direction.vectorFloat2Value = vector_float2(Float(normX), Float(normY))
            layer.streak.floatValue = Float(layer.tiled ? speedRatio *
                (thrusting ? 0.85 : 0.45) : 0)
            layer.warp.floatValue = Float(warpEnergy *
                (0.34 + layer.perspective * 0.43))
            let breath = 0.94 + 0.06 * sin(time * 0.14 + phase)
            let beltBoost: CGFloat = index == 5 ? 0.5 + currentDensity * 0.65 : 1
            for tile in layer.tiles {
                tile.alpha = layer.baseOpacity * breath * beltBoost
            }
        }
        if lensLocation != nil { updateLens() }
    }

    private func positionLayers() {
        let width = sceneSize.width
        let height = sceneSize.height
        for layer in layers {
            if layer.tiled {
                let offsetX = (travel.dx * layer.perspective)
                    .truncatingRemainder(dividingBy: width)
                let offsetY = (travel.dy * layer.perspective)
                    .truncatingRemainder(dividingBy: height)
                for (tile, coordinate) in zip(layer.tiles, layer.gridOffsets) {
                    tile.position = CGPoint(x: width * (0.5 + coordinate.x) + offsetX,
                                            y: height * (0.5 + coordinate.y) + offsetY)
                }
            } else {
                // Nonrepeating gas banks are 152% the viewport size. Their
                // bounded shifts create visible depth without hard panel edges.
                let x = sin(travel.dx / max(1, width * 0.56)) *
                    width * 0.17 * layer.perspective
                let y = sin(travel.dy / max(1, height * 0.62)) *
                    height * 0.15 * layer.perspective
                layer.tiles[0].position = CGPoint(x: width * 0.5 + x,
                                                  y: height * 0.5 + y)
            }
        }
    }

    func lens(at location: CGPoint?, intensity: CGFloat = 1) {
        lensLocation = location
        lensIntensity = max(0, min(1, intensity))
        updateLens()
    }

    private func updateLens() {
        for layer in layers {
            guard let location = lensLocation else {
                layer.lens.floatValue = 0
                continue
            }
            layer.lens.floatValue = Float(lensIntensity)
            for (tile, center) in zip(layer.tiles, layer.lensCenters) {
                center.vectorFloat2Value = vector_float2(
                    Float((location.x - tile.position.x) / tile.size.width + 0.5),
                    Float((location.y - tile.position.y) / tile.size.height + 0.5))
            }
        }
    }

    // MARK: - Vector artwork

    private func createLayers(transition: Bool = false) {
        let oldGroup = backdropGroup
        let group = SKNode()
        group.zPosition = 0
        addChild(group)
        backdropGroup = group
        layers.removeAll()
        travel = .zero
        lastTime = nil
        sceneGeneration += 1

        // Each call generates fresh randomized stars, cluster layouts,
        // gas boundaries, filaments and dust.
        addLayer(texture: makeStars(), depth: -17,
                 opacity: 1, parallax: 0.32, morph: 0, phase: 0)
        addLayer(texture: makeClouds(tier: 0, blur: 34), depth: -16,
                 opacity: 0.82, parallax: 0.35, morph: 0.009, phase: 1.3)
        addLayer(texture: makeClouds(tier: 1, blur: 17), depth: -15,
                 opacity: 0.88, parallax: 0.65, morph: 0.016, phase: 3.7)
        addLayer(texture: makeClouds(tier: 2, blur: 5), depth: -14,
                 opacity: 0.70, parallax: 1.00, morph: 0.022, phase: 5.9)
        addLayer(texture: makeFilaments(), depth: -13,
                 opacity: 0.52, parallax: 0.90, morph: 0.008, phase: 2.8)
        addLayer(texture: makeDust(), depth: -12,
                 opacity: 0.36, parallax: 1.55, morph: 0.003, phase: 4.5)

        positionLayers()
        updateLens()

        if let oldGroup {
            group.alpha = 0
            group.run(.fadeIn(withDuration: 1.5))
            oldGroup.run(.sequence([
                .fadeOut(withDuration: 1.5),
                .removeFromParent()
            ]))
        } else {
            group.alpha = 1
        }
    }

    private func addLayer(texture: SKTexture, depth: CGFloat,
                          opacity: CGFloat, parallax: CGFloat,
                          morph: Float, phase: CGFloat) {
        let tiled = depth == -17 || depth == -12
        let time = SKUniform(name: "u_time", float: 0)
        let drift = SKUniform(name: "u_drift", vectorFloat2: vector_float2(0, 0))
        let lens = SKUniform(name: "u_lensStrength", float: 0)
        let morphUniform = SKUniform(name: "u_morph", float: morph)
        let warp = SKUniform(name: "u_warp", float: 0)
        let aspect = SKUniform(name: "u_aspect",
                               float: Float(sceneSize.width / sceneSize.height))
        let wrap = SKUniform(name: "u_wrap", float: tiled ? 1 : 0)
        let direction = SKUniform(name: "u_direction", vectorFloat2: vector_float2(0, 0))
        let streak = SKUniform(name: "u_streak", float: 0)

        var tiles: [SKSpriteNode] = []
        var lensCenters: [SKUniform] = []
        var gridOffsets: [CGPoint] = []

        let coordinates: [CGPoint] = tiled
            ? (-1...1).flatMap { x in
                (-1...1).map { y in CGPoint(x: CGFloat(x), y: CGFloat(y)) }
              }
            : [CGPoint.zero]

        for coordinate in coordinates {
            let center = SKUniform(name: "u_lensCenter",
                                    vectorFloat2: vector_float2(0.5, 0.5))
            let shader = SKShader(source: Self.flowAndLensingShader)
            shader.uniforms = [time, drift, center, lens, morphUniform,
                               warp, aspect, wrap, direction, streak]

            let multiplier: CGFloat = tiled ? 1 : 1.52
            let sprite = SKSpriteNode(texture: texture,
                size: CGSize(width: sceneSize.width * multiplier,
                             height: sceneSize.height * multiplier))
            sprite.position = CGPoint(x: sceneSize.width / 2,
                                      y: sceneSize.height / 2)
            sprite.zPosition = depth
            sprite.alpha = opacity
            sprite.shader = shader
            sprite.blendMode = depth == -17 ? .alpha : .add
            backdropGroup?.addChild(sprite)

            tiles.append(sprite)
            lensCenters.append(center)
            gridOffsets.append(coordinate)
        }

        layers.append(AnimatedLayer(tiles: tiles, lensCenters: lensCenters,
                                    gridOffsets: gridOffsets, tiled: tiled,
                                    time: time, drift: drift, lens: lens,
                                    morph: morphUniform, warp: warp,
                                    aspect: aspect, direction: direction,
                                    streak: streak, perspective: parallax,
                                    baseOpacity: opacity, phase: phase))
    }

    /// All layers, including stars and sharp filaments, use the same radial
    /// gravitational lens. Gas gets more displacement than stellar points.
    private static let flowAndLensingShader = """
    float cloudNoise(vec2 p) {
        vec2 i = floor(p), f = fract(p);
        f = f*f*(3.0 - 2.0*f);
        float a = fract(sin(dot(i, vec2(127.1,311.7))) * 43758.5453);
        float b = fract(sin(dot(i+vec2(1.,0.), vec2(127.1,311.7))) * 43758.5453);
        float c = fract(sin(dot(i+vec2(0.,1.), vec2(127.1,311.7))) * 43758.5453);
        float d = fract(sin(dot(i+vec2(1.,1.), vec2(127.1,311.7))) * 43758.5453);
        return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
    }

    void main() {
        vec2 uv = v_tex_coord;
        float t = u_time;
        float n1 = cloudNoise(uv * 5.6 + vec2(t*.045, -t*.032));
        float n2 = cloudNoise(uv * 11.9 + vec2(-t*.066, t*.049));
        vec2 flow = vec2(
            sin(uv.y * 10.1 + t*.15) * .56 + (n1-.5)*.68,
            cos(uv.x * 8.9 - t*.12) * .54 + (n2-.5)*.65
        );
        vec2 deformed = uv + flow * u_morph - u_drift;

        // A short warp accent is a depth-dependent zoom, not a moving sprite.
        deformed = (deformed-.5) * (1.0-u_warp*.060) + .5;

        vec2 delta = deformed - u_lensCenter;
        vec2 metric = vec2(delta.x * u_aspect, delta.y);
        float r = length(metric);
        float annulus = smoothstep(.014,.049,r) *
                        (1.0-smoothstep(.19,.32,r));
        vec2 normal = metric / max(r,.0001);
        vec2 deflection = vec2(normal.x / max(u_aspect,.001),normal.y) *
                          (u_lensStrength*.032*annulus/(.50+r*7.0));
        vec2 sampleUV = deformed + deflection;

        vec4 pixel = vec4(0.0);
        if (u_wrap > 0.5) {
            // Stars/dust repeat: travel never stops at an arbitrary boundary.
            vec2 repeatUV = fract(sampleUV);
            pixel = texture2D(u_texture, repeatUV);
            if (u_streak > 0.02) {
                // Only a faint optical trail on star/dust points while moving.
                vec2 trailUV = fract(repeatUV + u_direction * 0.004 * u_streak);
                vec4 trail = texture2D(u_texture, trailUV);
                pixel.rgb = max(pixel.rgb, trail.rgb * 0.44 * u_streak);
            }
        } else if (sampleUV.x >= 0.0 && sampleUV.x <= 1.0 &&
                   sampleUV.y >= 0.0 && sampleUV.y <= 1.0) {
            pixel = texture2D(u_texture, sampleUV);
            // Feather finite gas contours before the source image's boundary,
            // preventing rectangular cutoffs when the viewpoint shifts.
            float border = smoothstep(0.0, 0.075, sampleUV.x) *
                           smoothstep(0.0, 0.075, sampleUV.y) *
                           (1.0 - smoothstep(0.925, 1.0, sampleUV.x)) *
                           (1.0 - smoothstep(0.925, 1.0, sampleUV.y));
            pixel *= border;
        }
        gl_FragColor = pixel * v_color_mix;
    }
    """

    private func makeCanvas(scale: CGFloat = 0.72) -> CGContext? {
        let factor = min(1, max(0.36, scale))
        let width = max(1, Int(ceil(sceneSize.width * factor)))
        let height = max(1, Int(ceil(sceneSize.height * factor)))
        guard let ctx = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.scaleBy(x: factor, y: factor)
        return ctx
    }

    private func makeTexture(_ ctx: CGContext?, blur: CGFloat = 0) -> SKTexture {
        guard let image = ctx?.makeImage() else { return SKTexture(image: NSImage(size: sceneSize)) }
        let finalImage: CGImage
        if blur > 0 {
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = CIImage(cgImage: image)
            filter.radius = Float(blur)
            let ciContext = CIContext(options: [.useSoftwareRenderer: false])
            if let output = filter.outputImage?.cropped(to: CGRect(
                x: 0, y: 0, width: image.width, height: image.height)),
                let softened = ciContext.createCGImage(output, from: CGRect(
                    x: 0, y: 0, width: image.width, height: image.height)) {
                finalImage = softened
            } else { finalImage = image }
        } else { finalImage = image }
        let texture = SKTexture(cgImage: finalImage)
        texture.filteringMode = .linear
        return texture
    }

    /// Organic cloud contours: a low-frequency sum of waves perturbs radii,
    /// then a closed cubic B-spline-like path smooths all transitions.
    private func cloudPath(center: CGPoint, rx: CGFloat, ry: CGFloat,
                           seed: CGFloat) -> CGPath {
        let segments = 30
        var points: [CGPoint] = []
        for k in 0..<segments {
            let angle = CGFloat(k) / CGFloat(segments) * .pi * 2
            let scale = 1
                + 0.19 * sin(angle * 3 + seed)
                + 0.11 * sin(angle * 5 - seed * 1.9)
                + 0.07 * cos(angle * 9 + seed * 2.7)
                + 0.04 * sin(angle * 13 - seed * 0.65)
            points.append(CGPoint(x: center.x + cos(angle) * rx * scale,
                                  y: center.y + sin(angle) * ry * scale))
        }
        let p = CGMutablePath()
        p.move(to: points[0])
        for i in 0..<segments {
            let a = points[(i + segments - 1) % segments]
            let b = points[i]
            let c = points[(i + 1) % segments]
            let d = points[(i + 2) % segments]
            let tension: CGFloat = 0.15
            let first = CGPoint(x: b.x + (c.x-a.x)*tension,
                                y: b.y + (c.y-a.y)*tension)
            let second = CGPoint(x: c.x - (d.x-b.x)*tension,
                                 y: c.y - (d.y-b.y)*tension)
            p.addCurve(to: c, control1: first, control2: second)
        }
        p.closeSubpath()
        return p
    }

    private func drawCloud(in ctx: CGContext, center: CGPoint,
                           rx: CGFloat, ry: CGFloat,
                           color: (CGFloat, CGFloat, CGFloat),
                           alpha: CGFloat, seed: CGFloat,
                           rim: CGFloat = 0) {
        let shape = cloudPath(center: center, rx: rx, ry: ry, seed: seed)
        ctx.saveGState()
        ctx.addPath(shape)
        ctx.clip()
        let inner = CGColor(red: color.0, green: color.1, blue: color.2,
                            alpha: alpha)
        let outer = CGColor(red: color.0 * 0.40, green: color.1 * 0.40,
                            blue: color.2 * 0.40, alpha: 0)
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: [inner, outer] as CFArray,
                                     locations: [0,1]) {
            ctx.drawRadialGradient(gradient,
                startCenter: CGPoint(x: center.x-rx*0.14, y: center.y+ry*0.18),
                startRadius: 0, endCenter: center,
                endRadius: max(rx,ry)*1.15,
                options: [.drawsAfterEndLocation])
        }
        ctx.restoreGState()
        if rim > 0 {
            ctx.addPath(shape)
            ctx.setStrokeColor(CGColor(red: color.0, green: color.1,
                                       blue: color.2, alpha: rim))
            ctx.setLineWidth(1.2)
            ctx.strokePath()
        }
    }

    private func makeClouds(tier: Int, blur: CGFloat) -> SKTexture {
        let scale: CGFloat = 0.72
        guard let ctx = makeCanvas(scale: scale) else { return makeTexture(nil) }
        let w = sceneSize.width, h = sceneSize.height
        let count = [34, 63, 78][tier]
        for k in 0..<count {
            let x = CGFloat(k)/CGFloat(count) * (w*1.28)-w*0.12 +
                    CGFloat.random(in: -w*0.07...w*0.07)
            let ridge = h*(0.42 + 0.16*sin(x/w*6.2 + 0.7))
            let y = ridge + CGFloat.random(in: -h*0.22...h*0.22)
            let rx: CGFloat = tier == 0 ? CGFloat.random(in: 95...235)
                : tier == 1 ? CGFloat.random(in: 49...132)
                : CGFloat.random(in: 24...80)
            let ry = rx * CGFloat.random(in: 0.38...0.98)
            let color: (CGFloat, CGFloat, CGFloat)
            if tier == 0 {
                color = Bool.random() ? (0.13, 0.36, 0.74) : (0.38, 0.13, 0.57)
            } else if tier == 1 {
                color = k.isMultiple(of: 3) ? (0.68,0.25,0.10)
                    : k.isMultiple(of: 2) ? (0.18,0.50,0.79) : (0.60,0.23,0.55)
            } else {
                color = k.isMultiple(of: 3) ? (0.85,0.43,0.15)
                    : (0.22,0.64,0.87)
            }
            drawCloud(in: ctx, center: CGPoint(x:x, y:y), rx:rx, ry:ry,
                      color:color, alpha: tier==0 ? 0.31 : tier==1 ? 0.25 : 0.17,
                      seed:CGFloat(k)*0.89+CGFloat(tier),
                      rim:tier==2 ? 0.06 : 0)
        }

        // Dark foreground voids carve depth into the cloud bank.
        if tier == 1 {
            for k in 0..<19 {
                let x = CGFloat.random(in: -40...(w+40))
                let ridge = h*(0.42 + 0.16*sin(x/w*6.2+0.7))
                drawCloud(in:ctx, center:CGPoint(x:x,y:ridge+CGFloat.random(in:-45...45)),
                          rx:CGFloat.random(in:35...115),
                          ry:CGFloat.random(in:18...62),
                          color:(0.005,0.010,0.027), alpha:0.32,
                          seed:CGFloat(k)*1.3)
            }
        }
        return makeTexture(ctx, blur: blur * scale)
    }

    private func makeStars() -> SKTexture {
        guard let ctx = makeCanvas(scale: 1) else { return makeTexture(nil) }
        let w=sceneSize.width, h=sceneSize.height
        ctx.setFillColor(CGColor(red:0.003,green:0.006,blue:0.022,alpha:1))
        ctx.fill(CGRect(origin:.zero,size:sceneSize))

        // Wide random background stars and four dense, structured clusters.
        for _ in 0..<1150 {
            star(in:ctx, at:CGPoint(x:CGFloat.random(in:0...w),
                                   y:CGFloat.random(in:0...h)),
                 radius:CGFloat.random(in:0.3...1.05),
                 alpha:CGFloat.random(in:0.12...0.57))
        }
        let clusters: [(CGFloat,CGFloat,CGFloat,CGFloat)] = [
            (0.20,0.75,0.070,0.080),(0.46,0.43,0.058,0.110),
            (0.78,0.61,0.086,0.076),(0.69,0.18,0.060,0.064)
        ]
        for (cx,cy,sx,sy) in clusters {
            for _ in 0..<225 {
                let p=CGPoint(x:cx*w + bell()*sx*w, y:cy*h + bell()*sy*h)
                guard p.x>0 && p.x<w && p.y>0 && p.y<h else { continue }
                star(in:ctx,at:p,radius:CGFloat.random(in:0.35...1.30),
                     alpha:CGFloat.random(in:0.24...0.78))
            }
        }
        for _ in 0..<13 {
            let p=CGPoint(x:CGFloat.random(in:0.07...0.93)*w,
                          y:CGFloat.random(in:0.10...0.90)*h)
            diffractionStar(in:ctx, at:p,
                            radius:CGFloat.random(in:9...21))
        }

        // Subtle elliptical galaxies are vector paths, not photographic panels.
        for _ in 0..<5 {
            let p=CGPoint(x:CGFloat.random(in:0.1...0.9)*w,
                          y:CGFloat.random(in:0.1...0.9)*h)
            ctx.saveGState()
            ctx.translateBy(x:p.x,y:p.y)
            ctx.rotate(by:CGFloat.random(in:0...(.pi)))
            for ring in (1...7).reversed() {
                let r=CGFloat(ring)*5
                ctx.setStrokeColor(CGColor(red:0.54,green:0.69,blue:0.89,
                                            alpha:0.025+CGFloat(8-ring)*0.009))
                ctx.setLineWidth(1.6)
                ctx.strokeEllipse(in:CGRect(x:-r,y:-r*0.28,width:r*2,height:r*0.56))
            }
            ctx.restoreGState()
        }
        return makeTexture(ctx)
    }

    private func star(in ctx:CGContext,at p:CGPoint,radius:CGFloat,alpha:CGFloat) {
        let warm = Int.random(in:0...9)==0
        ctx.setFillColor(CGColor(red:warm ? 1 : 0.75,
                                 green:warm ? 0.82 : 0.88,
                                 blue:warm ? 0.62 : 1,
                                 alpha:alpha))
        ctx.fillEllipse(in:CGRect(x:p.x-radius,y:p.y-radius,
                                  width:radius*2,height:radius*2))
    }

    private func diffractionStar(in ctx:CGContext,at p:CGPoint,radius:CGFloat) {
        let glow=CGColor(red:0.63,green:0.78,blue:1,alpha:0.26)
        let clear=CGColor(red:0.63,green:0.78,blue:1,alpha:0)
        if let grad=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),
                               colors:[glow,clear] as CFArray,locations:[0,1]) {
            ctx.drawRadialGradient(grad,startCenter:p,startRadius:0,
                                   endCenter:p,endRadius:radius,
                                   options:[.drawsAfterEndLocation])
        }
        ctx.setFillColor(CGColor(red:0.92,green:0.96,blue:1,alpha:0.92))
        ctx.fillEllipse(in:CGRect(x:p.x-1.8,y:p.y-1.8,width:3.6,height:3.6))
        for k in 0..<6 {
            let angle=CGFloat(k)*(.pi/3)
            let length=radius*(k.isMultiple(of:2) ? 1.1 : 0.65)
            ctx.move(to:p)
            ctx.addLine(to:CGPoint(x:p.x+cos(angle)*length,
                                   y:p.y+sin(angle)*length))
            ctx.setStrokeColor(CGColor(red:0.82,green:0.90,blue:1,alpha:0.32))
            ctx.setLineWidth(0.8)
            ctx.strokePath()
        }
    }

    private func bell() -> CGFloat {
        let a=max(0.000001,CGFloat.random(in:0...1))
        let b=CGFloat.random(in:0...1)
        return sqrt(-2 * log(a)) * cos(2 * CGFloat.pi * b)
    }

    /// Sparse illuminated gas fronts, connected to the same serpentine ridge
    /// used to place the cloud banks. No random squiggles across empty space.
    /// Small side branches and double strokes suggest charged cloud edges.
    private func makeFilaments() -> SKTexture {
        guard let ctx = makeCanvas(scale: 0.85) else { return makeTexture(nil) }
        let width = sceneSize.width, height = sceneSize.height
        let fronts = 23

        func ridge(_ x: CGFloat) -> CGFloat {
            height * (0.42 + 0.16 * sin(x / width * 6.2 + 0.7))
        }

        for index in 0..<fronts {
            let startX = (CGFloat(index) + CGFloat.random(in: -0.24...0.24)) /
                CGFloat(fronts) * width
            let offset = CGFloat.random(in: -height * 0.055...height * 0.055)
            let span = CGFloat.random(in: 48...125)
            let from = CGPoint(x: startX, y: ridge(startX) + offset)

            // Each filament hugs an existing gas front with local irregularity
            // and only travels partway across its supporting cloud mass.
            let endX = startX + span
            let end = CGPoint(x: endX,
                              y: ridge(endX) + offset * 0.58 +
                                 CGFloat.random(in: -13...13))
            let midpointX = startX + span * 0.52
            let midpoint = CGPoint(x: midpointX,
                                   y: ridge(midpointX) + offset * 0.8 +
                                      CGFloat.random(in: -9...9))
            let curve = CGMutablePath()
            curve.move(to: from)
            curve.addQuadCurve(to: midpoint,
                control: CGPoint(x: startX + span * 0.24,
                                 y: ridge(startX + span * 0.24) + offset))
            curve.addQuadCurve(to: end,
                control: CGPoint(x: startX + span * 0.78,
                                 y: ridge(startX + span * 0.78) + offset * 0.62))

            let amber = index.isMultiple(of: 3)
            let red: CGFloat = amber ? 0.94 : 0.39
            let green: CGFloat = amber ? 0.57 : 0.82
            let blue: CGFloat = amber ? 0.27 : 0.98

            // A broad translucent rim with a much narrower, dimmer highlight.
            for (width, alpha) in [(CGFloat(5.0), CGFloat(0.035)),
                                   (CGFloat(1.15), CGFloat(0.20))] {
                ctx.addPath(curve)
                ctx.setStrokeColor(CGColor(red: red, green: green, blue: blue,
                                           alpha: alpha))
                ctx.setLineWidth(width)
                ctx.setLineCap(.round)
                ctx.strokePath()
            }

            // Only some fronts have short tributary filaments; these peel away
            // from the gas wall instead of forming an unrelated sine-wave field.
            if index.isMultiple(of: 4) {
                let branch = CGMutablePath()
                branch.move(to: midpoint)
                branch.addQuadCurve(
                    to: CGPoint(x: midpoint.x + span * 0.27,
                                y: midpoint.y + CGFloat.random(in: 12...33)),
                    control: CGPoint(x: midpoint.x + span * 0.12,
                                     y: midpoint.y + 18))
                ctx.addPath(branch)
                ctx.setStrokeColor(CGColor(red: red, green: green, blue: blue,
                                           alpha: 0.12))
                ctx.setLineWidth(0.8)
                ctx.strokePath()
            }
        }
        return makeTexture(ctx, blur: 1.15)
    }

    private func makeDust() -> SKTexture {
        guard let ctx=makeCanvas(scale:0.85) else { return makeTexture(nil) }
        let w=sceneSize.width,h=sceneSize.height
        for _ in 0..<460 {
            let x=CGFloat.random(in:0...w)
            let y = h * (0.42 + 0.16 * sin(x / w * 6.2 + 0.7)) +
                CGFloat.random(in: (-h * 0.27)...(h * 0.27))
            let radius=CGFloat.random(in:0.35...1.4)
            ctx.setFillColor(CGColor(red:0.55,green:0.72,blue:0.92,
                                     alpha:CGFloat.random(in:0.06...0.22)))
            ctx.fillEllipse(in:CGRect(x:x-radius,y:y-radius,
                                     width:2*radius,height:2*radius))
        }
        return makeTexture(ctx)
    }
}
