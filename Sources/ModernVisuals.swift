import AppKit
import SpriteKit

/// Original, entirely procedural artwork for the optional Modern Vector style.
enum ModernVisuals {
    static let ice = SKColor(calibratedRed: 0.35, green: 0.91, blue: 1.0, alpha: 1)
    static let fire = SKColor(calibratedRed: 1.0, green: 0.53, blue: 0.17, alpha: 1)
    static let rock = SKColor(calibratedRed: 0.12, green: 0.22, blue: 0.34, alpha: 0.94)

    static func backdrop(size: CGSize) -> SKNode {
        let layer = SKNode()
        layer.zPosition = -20

        let nebulae: [(CGFloat, CGFloat, CGFloat, SKColor)] = [
            (0.21, 0.73, 195.0, SKColor(calibratedRed: 0.12, green: 0.35, blue: 0.65, alpha: 0.08)),
            (0.77, 0.25, 155.0, SKColor(calibratedRed: 0.45, green: 0.13, blue: 0.66, alpha: 0.09)),
            (0.63, 0.86, 110.0, SKColor(calibratedRed: 0.08, green: 0.52, blue: 0.58, alpha: 0.06))
        ]
        for (x, y, radius, color) in nebulae {
            let haze = SKShapeNode(circleOfRadius: radius)
            haze.position = CGPoint(x: size.width * x, y: size.height * y)
            haze.fillColor = color
            haze.strokeColor = .clear
            haze.glowWidth = 95
            layer.addChild(haze)
        }

        for _ in 0..<135 {
            let r = CGFloat.random(in: 0.45...1.65)
            let star = SKShapeNode(circleOfRadius: r)
            star.position = CGPoint(
                x: CGFloat.random(in: 0...max(1, size.width)),
                y: CGFloat.random(in: 0...max(1, size.height))
            )
            star.fillColor = Bool.random() ? ice : .white
            star.strokeColor = .clear
            star.alpha = CGFloat.random(in: 0.14...0.65)
            let baseline = star.alpha
            let duration = Double.random(in: 1.3...3.7)
            star.run(.repeatForever(.sequence([
                .fadeAlpha(to: max(0.08, baseline * 0.3), duration: duration),
                .fadeAlpha(to: baseline, duration: duration)
            ])))
            layer.addChild(star)
        }
        return layer
    }

    /// Local-coordinate rock features rotate with the rock and are hidden in Classic.
    static func asteroidDetail(radius: CGFloat, vertices: [CGPoint]) -> SKNode {
        let detail = SKNode()
        detail.isHidden = true
        guard vertices.count > 5 else { return detail }

        let segments = radius > 35 ? 7 : radius > 22 ? 5 : 3
        for i in 0..<segments {
            let start = vertices[(i * 2) % vertices.count]
            let end = vertices[(i * 2 + 3) % vertices.count]
            let center = CGPoint(
                x: CGFloat.random(in: -0.16...0.16) * radius,
                y: CGFloat.random(in: -0.16...0.16) * radius
            )
            let path = CGMutablePath()
            path.move(to: CGPoint(x: start.x * 0.78, y: start.y * 0.78))
            path.addLine(to: center)
            path.addLine(to: CGPoint(x: end.x * 0.80, y: end.y * 0.80))
            path.closeSubpath()

            let facet = SKShapeNode(path: path)
            facet.fillColor = i.isMultiple(of: 2)
                ? SKColor(calibratedRed: 0.15, green: 0.35, blue: 0.51, alpha: 0.24)
                : SKColor(calibratedRed: 0.03, green: 0.10, blue: 0.20, alpha: 0.42)
            facet.strokeColor = SKColor(calibratedRed: 0.35, green: 0.68, blue: 0.83, alpha: 0.37)
            facet.lineWidth = 0.9
            detail.addChild(facet)
        }

        for _ in 0..<(radius > 25 ? 3 : 1) {
            let craterSize = CGFloat.random(in: 3.5...7) * radius / 43
            let crater = SKShapeNode(ellipseOf: CGSize(
                width: craterSize * 1.5, height: craterSize
            ))
            crater.position = CGPoint(
                x: CGFloat.random(in: -0.36...0.36) * radius,
                y: CGFloat.random(in: -0.36...0.36) * radius
            )
            crater.zRotation = CGFloat.random(in: 0...(.pi))
            crater.fillColor = SKColor(calibratedRed: 0.02, green: 0.06, blue: 0.13, alpha: 0.78)
            crater.strokeColor = SKColor(calibratedRed: 0.37, green: 0.79, blue: 0.90, alpha: 0.47)
            crater.lineWidth = 1
            detail.addChild(crater)
        }
        return detail
    }

    static func shipDetail() -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 12))
        path.addLine(to: CGPoint(x: 0, y: -4))
        path.move(to: CGPoint(x: -9, y: -10))
        path.addLine(to: CGPoint(x: -4, y: -3))
        path.addLine(to: CGPoint(x: 4, y: -3))
        path.addLine(to: CGPoint(x: 9, y: -10))
        let detail = SKShapeNode(path: path)
        detail.strokeColor = ice.withAlphaComponent(0.8)
        detail.lineWidth = 1.25
        detail.glowWidth = 2
        detail.isHidden = true
        return detail
    }

    static func engineFlame() -> SKShapeNode {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -5, y: -8))
        p.addLine(to: CGPoint(x: -3, y: -20))
        p.addLine(to: CGPoint(x: 0, y: -33))
        p.addLine(to: CGPoint(x: 3, y: -20))
        p.addLine(to: CGPoint(x: 5, y: -8))
        let flame = SKShapeNode(path: p)
        flame.fillColor = fire.withAlphaComponent(0.18)
        flame.strokeColor = fire
        flame.lineWidth = 2
        flame.glowWidth = 8
        flame.zPosition = -1
        flame.isHidden = true
        return flame
    }

    /// Tail is oriented along negative X; caller rotates the comet to its heading.
    static func cometNode() -> SKNode {
        let node = SKNode()
        node.zPosition = 9

        for strand in -2...2 {
            let offset = CGFloat(strand)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -8, y: offset * 4))
            path.addQuadCurve(
                to: CGPoint(x: -190 - CGFloat.random(in: 0...70), y: offset * 22),
                control: CGPoint(x: -90, y: offset * 11)
            )
            let trail = SKShapeNode(path: path)
            trail.lineWidth = strand == 0 ? 5 : 2.5
            trail.strokeColor = strand.isMultiple(of: 2) ? ice : fire.withAlphaComponent(0.7)
            trail.glowWidth = strand == 0 ? 18 : 9
            trail.alpha = CGFloat.random(in: 0.50...0.95)
            node.addChild(trail)
            let a = trail.alpha
            trail.run(.repeatForever(.sequence([
                .fadeAlpha(to: a * 0.42, duration: Double.random(in: 0.2...0.5)),
                .fadeAlpha(to: a, duration: 0.3)
            ])))
        }

        let halo = SKShapeNode(circleOfRadius: 24)
        halo.fillColor = ice.withAlphaComponent(0.16)
        halo.strokeColor = .clear
        halo.glowWidth = 28
        node.addChild(halo)

        let head = SKShapeNode(circleOfRadius: 12)
        head.fillColor = .white
        head.strokeColor = ice
        head.lineWidth = 3
        head.glowWidth = 18
        node.addChild(head)

        let kernel = SKShapeNode(circleOfRadius: 4)
        kernel.fillColor = .white
        kernel.strokeColor = .clear
        kernel.glowWidth = 9
        node.addChild(kernel)
        return node
    }

    static func cometSpark(in layer: SKNode, at position: CGPoint, direction: CGVector) {
        let p = CGPoint(
            x: position.x + CGFloat.random(in: -10...10),
            y: position.y + CGFloat.random(in: -10...10)
        )
        let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...3))
        dot.position = p
        dot.fillColor = Bool.random() ? ice : fire
        dot.strokeColor = .clear
        dot.glowWidth = 4
        layer.addChild(dot)
        let travel = Double.random(in: 0.35...0.8)
        let dx = -direction.dx * CGFloat(travel) * CGFloat.random(in: 0.2...0.5)
        let dy = -direction.dy * CGFloat(travel) * CGFloat.random(in: 0.2...0.5)
        dot.run(.sequence([
            .group([.moveBy(x: dx, y: dy, duration: travel), .fadeOut(withDuration: travel)]),
            .removeFromParent()
        ]))
    }

    static func burst(in layer: SKNode, at point: CGPoint, color: SKColor, count: Int) {
        for _ in 0..<count {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 55...230)
            let duration = Double.random(in: 0.30...0.75)
            let length = CGFloat.random(in: 4...13)
            let fragment = SKShapeNode(rectOf: CGSize(width: 1.6, height: length))
            fragment.position = point
            fragment.zRotation = angle - .pi / 2
            fragment.fillColor = color
            fragment.strokeColor = .clear
            fragment.glowWidth = 5
            layer.addChild(fragment)
            let dx = cos(angle) * speed * CGFloat(duration)
            let dy = sin(angle) * speed * CGFloat(duration)
            fragment.run(.sequence([
                .group([
                    .moveBy(x: dx, y: dy, duration: duration),
                    .fadeOut(withDuration: duration),
                    .rotate(byAngle: CGFloat.random(in: -2...2), duration: duration)
                ]),
                .removeFromParent()
            ]))
        }
    }

    static func shockRing(at point: CGPoint) -> SKShapeNode {
        let ring = SKShapeNode(circleOfRadius: 12)
        ring.position = point
        ring.strokeColor = ice
        ring.fillColor = .clear
        ring.lineWidth = 4
        ring.glowWidth = 24
        ring.zPosition = 8
        return ring
    }

    static func floatScore(_ text: String, in layer: SKNode, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 22
        label.fontColor = fire
        label.position = position
        label.zPosition = 20
        layer.addChild(label)
        label.run(.sequence([
            .group([
                .moveBy(x: 0, y: 65, duration: 1.1),
                .fadeOut(withDuration: 1.1)
            ]),
            .removeFromParent()
        ]))
    }
}
