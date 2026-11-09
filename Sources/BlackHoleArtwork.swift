import AppKit
import SceneKit
import SpriteKit

/// Compact, original astronomical black-hole visuals. The dark event horizon
/// is the focus: emission is confined to a thin photon ring and an inclined,
/// softly moving accretion disk. Nothing resembles a neon portal.
enum BlackHoleArtwork {
    static func classic() -> SKNode {
        let node = SKNode()
        let outer = SKShapeNode(circleOfRadius: 31)
        outer.fillColor = .clear
        outer.strokeColor = SKColor(white: 0.78, alpha: 0.36)
        outer.lineWidth = 0.9
        node.addChild(outer)

        let horizon = SKShapeNode(circleOfRadius: 23)
        horizon.fillColor = .black
        horizon.strokeColor = .white
        horizon.lineWidth = 1.8
        node.addChild(horizon)
        return node
    }

    /// SceneKit's real XYZ counterpart: a black sphere with several thin,
    /// gently tilted accretion rings and a few dim orbiting dust fragments.
    static func flight3D() -> SCNNode {
        let root = SCNNode()
        let core = SCNNode(geometry: SCNSphere(radius: 4.5))
        core.geometry?.firstMaterial?.diffuse.contents = NSColor.black
        core.geometry?.firstMaterial?.emission.contents = NSColor.black
        core.geometry?.firstMaterial?.lightingModel = .constant
        root.addChildNode(core)

        let disc = SCNNode()
        disc.eulerAngles = SCNVector3(CGFloat.pi * 0.21, 0, CGFloat.pi * 0.09)
        root.addChildNode(disc)

        let bands: [(CGFloat, CGFloat, NSColor)] = [
            (6.4, 0.15, NSColor(calibratedRed: 0.70, green: 0.72, blue: 0.72, alpha: 0.65)),
            (7.5, 0.30, NSColor(calibratedRed: 0.67, green: 0.48, blue: 0.32, alpha: 0.48)),
            (9.3, 0.12, NSColor(calibratedWhite: 0.62, alpha: 0.26)),
            (10.6, 0.08, NSColor(calibratedWhite: 0.56, alpha: 0.14))
        ]
        for (radius, tube, color) in bands {
            let ring = SCNNode(geometry: SCNTorus(ringRadius: radius, pipeRadius: tube))
            ring.geometry?.firstMaterial?.diffuse.contents = color
            ring.geometry?.firstMaterial?.emission.contents = color
            ring.geometry?.firstMaterial?.lightingModel = .constant
            ring.geometry?.firstMaterial?.isDoubleSided = true
            disc.addChildNode(ring)
        }

        for i in 0..<26 {
            let theta = CGFloat(i) * 2 * .pi / 26
            let radius = CGFloat.random(in: 7.0...10.4)
            let grain = SCNNode(geometry: SCNSphere(radius: CGFloat.random(in: 0.09...0.21)))
            let alpha: CGFloat = CGFloat.random(in: 0.24...0.55)
            let material = grain.geometry?.firstMaterial
            let color = NSColor(calibratedRed: 0.82, green: 0.68, blue: 0.49, alpha: alpha)
            material?.diffuse.contents = color
            material?.emission.contents = color
            material?.lightingModel = .constant
            grain.position = SCNVector3(cos(theta) * radius, 0, sin(theta) * radius)
            disc.addChildNode(grain)
        }
        return root
    }
}

final class ModernBlackHoleNode: SKNode {
    private struct Grain {
        let node: SKShapeNode
        let orbit: CGFloat
        let speed: CGFloat
        var angle: CGFloat
        let brightness: CGFloat
    }

    private var grains: [Grain] = []
    private let photonRing = SKNode()
    private let nearDisc = SKNode()
    private var age: CGFloat = 0
    private let discAngle: CGFloat = -0.19

    override init() {
        super.init()
        build()
    }

    required init?(coder: NSCoder) { nil }

    private func ellipseArc(rx: CGFloat, ry: CGFloat,
                            start: CGFloat, end: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let steps = 46
        let cosine = cos(discAngle)
        let sine = sin(discAngle)
        for i in 0...steps {
            let theta = start + (end - start) * CGFloat(i) / CGFloat(steps)
            let x = cos(theta) * rx
            let y = sin(theta) * ry
            let p = CGPoint(x: x * cosine - y * sine,
                            y: x * sine + y * cosine)
            if i == 0 { path.move(to: p) }
            else { path.addLine(to: p) }
        }
        return path
    }

    private func arc(rx: CGFloat, ry: CGFloat, start: CGFloat, end: CGFloat,
                     stroke: SKColor, width: CGFloat, glow: CGFloat = 0,
                     z: CGFloat) -> SKShapeNode {
        let shape = SKShapeNode(path: ellipseArc(rx: rx, ry: ry, start: start, end: end))
        shape.fillColor = .clear
        shape.strokeColor = stroke
        shape.lineWidth = width
        shape.glowWidth = glow
        shape.lineCap = .round
        shape.zPosition = z
        return shape
    }

    private func build() {
        // Outside the horizon, extremely faint concentric lensing hints provide
        // scale without pretending the black hole itself is a bright orb.
        for (radius, alpha, width) in [(CGFloat(67), CGFloat(0.10), CGFloat(1.1)),
                                       (CGFloat(91), CGFloat(0.055), CGFloat(0.9))] {
            let faint = SKShapeNode(circleOfRadius: radius)
            faint.fillColor = .clear
            faint.strokeColor = SKColor(white: 0.76, alpha: alpha)
            faint.lineWidth = width
            faint.zPosition = -8
            addChild(faint)
        }

        // Back of the accretion disk, partially hidden by the opaque horizon.
        addChild(arc(rx: 79, ry: 24, start: 0, end: .pi,
                     stroke: SKColor(calibratedRed: 0.70, green: 0.60, blue: 0.48,
                                     alpha: 0.14), width: 13, glow: 12, z: -6))
        addChild(arc(rx: 76, ry: 23, start: 0, end: .pi,
                     stroke: SKColor(white: 0.70, alpha: 0.33),
                     width: 1.65, glow: 3, z: -5))
        addChild(arc(rx: 58, ry: 18, start: 0, end: .pi,
                     stroke: SKColor(calibratedWhite: 0.65, alpha: 0.22),
                     width: 2, glow: 4, z: -4))

        // A gentle dark halo helps the silhouette stand out from the nebula.
        let shadow = SKShapeNode(circleOfRadius: 39)
        shadow.fillColor = SKColor(calibratedWhite: 0.0, alpha: 0.57)
        shadow.strokeColor = .clear
        shadow.zPosition = -2
        shadow.glowWidth = 6
        addChild(shadow)

        let horizon = SKShapeNode(circleOfRadius: 27)
        horizon.fillColor = .black
        horizon.strokeColor = SKColor(white: 0.29, alpha: 0.58)
        horizon.lineWidth = 0.9
        horizon.zPosition = 0
        addChild(horizon)

        // The narrow photon ring is bright on one side, much less bright on
        // the other; most of the visible object remains almost completely dark.
        let rim = SKShapeNode(circleOfRadius: 29.4)
        rim.fillColor = .clear
        rim.strokeColor = SKColor(calibratedWhite: 0.87, alpha: 0.57)
        rim.lineWidth = 1.25
        rim.glowWidth = 4
        rim.zPosition = 1
        photonRing.addChild(rim)

        let crescent = SKShapeNode()
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: 29.4,
                    startAngle: 3.55, endAngle: 5.30, clockwise: false)
        crescent.path = path
        crescent.fillColor = .clear
        crescent.strokeColor = SKColor(calibratedRed: 0.96, green: 0.88,
                                      blue: 0.74, alpha: 0.88)
        crescent.lineWidth = 2.1
        crescent.glowWidth = 8
        photonRing.addChild(crescent)
        photonRing.zPosition = 1
        addChild(photonRing)

        // Near edge of the disk appears in front of the horizon. Shorter
        // brighter sections create a gentle Doppler-boosted look.
        nearDisc.zPosition = 2
        nearDisc.addChild(arc(rx: 80, ry: 25, start: .pi, end: 2 * .pi,
                              stroke: SKColor(calibratedRed: 0.85, green: 0.65,
                                              blue: 0.46, alpha: 0.13),
                              width: 14, glow: 12, z: 0))
        nearDisc.addChild(arc(rx: 77, ry: 24, start: .pi, end: 2 * .pi,
                              stroke: SKColor(calibratedRed: 0.82, green: 0.79,
                                              blue: 0.71, alpha: 0.43),
                              width: 2.0, glow: 4, z: 1))
        nearDisc.addChild(arc(rx: 67, ry: 20, start: .pi, end: 2 * .pi,
                              stroke: SKColor(calibratedRed: 0.88, green: 0.73,
                                              blue: 0.57, alpha: 0.28),
                              width: 1.4, glow: 3, z: 2))
        nearDisc.addChild(arc(rx: 77, ry: 24, start: 3.45, end: 4.78,
                              stroke: SKColor(calibratedRed: 0.98, green: 0.91,
                                              blue: 0.80, alpha: 0.64),
                              width: 2.6, glow: 9, z: 3))
        addChild(nearDisc)

        // A few moving knots of matter, orbiting at different rates around
        // a flattened plane. They fade behind the horizon.
        for i in 0..<34 {
            let radius = CGFloat.random(in: 55...91)
            let theta = CGFloat.random(in: 0...(2 * .pi))
            let radiusPoint = CGFloat.random(in: 0.35...1.45)
            let mote = SKShapeNode(circleOfRadius: radiusPoint)
            mote.fillColor = i.isMultiple(of: 4)
                ? SKColor(calibratedWhite: 0.90, alpha: 0.8)
                : SKColor(calibratedRed: 0.83, green: 0.66, blue: 0.48, alpha: 0.65)
            mote.strokeColor = .clear
            mote.glowWidth = radiusPoint > 0.95 ? 2 : 0
            mote.zPosition = 3
            addChild(mote)
            grains.append(Grain(node: mote, orbit: radius,
                                speed: CGFloat.random(in: 0.11...0.29),
                                angle: theta,
                                brightness: CGFloat.random(in: 0.17...0.65)))
        }
        advance(dt: 0, remaining: 11)
    }

    func advance(dt: CGFloat, remaining: CGFloat) {
        age += max(0, dt)
        let appearing = min(1, age / 0.85)
        let departing = min(1, max(0, remaining / 1.1))
        alpha = appearing * departing
        nearDisc.alpha = 0.90 + 0.10 * sin(age * 0.9)
        photonRing.alpha = 0.93 + 0.07 * sin(age * 1.5)

        for index in grains.indices {
            grains[index].angle += dt * grains[index].speed
            let theta = grains[index].angle
            let rx = grains[index].orbit
            let ry = rx * 0.315
            let x = cos(theta) * rx
            let y = sin(theta) * ry
            let c = cos(discAngle), s = sin(discAngle)
            let mote = grains[index].node
            mote.position = CGPoint(x: x * c - y * s, y: x * s + y * c)
            let inFront = sin(theta) < 0
            mote.zPosition = inFront ? 4 : -3
            mote.alpha = grains[index].brightness * (inFront ? 1 : 0.46)
        }
    }
}
