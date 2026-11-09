import AppKit
import CoreGraphics
import SpriteKit

/// Bitmap-shaded, irregular rock surfaces generated locally at spawn time.
/// Classic never renders these textures. No art downloads or game assets.
enum ModernRockTextures {
    static func create(radius: CGFloat, outline vertices: [CGPoint]) -> SKSpriteNode {
        let side = Int(ceil(radius * 2 + 20))
        guard let context = CGContext(
            data: nil, width: side, height: side,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKSpriteNode() }

        let half = CGFloat(side) * 0.5
        let silhouette = CGMutablePath()
        for (index, point) in vertices.enumerated() {
            let p = CGPoint(x: half + point.x, y: half + point.y)
            if index == 0 { silhouette.move(to: p) }
            else { silhouette.addLine(to: p) }
        }
        silhouette.closeSubpath()

        context.saveGState()
        context.addPath(silhouette)
        context.clip()

        // Uneven mineral colors, directional light from the upper-left,
        // and a pronounced dark limb make the rock read as a solid body.
        let lit = CGColor(red: 0.45, green: 0.60, blue: 0.69, alpha: 1)
        let mid = CGColor(red: 0.20, green: 0.32, blue: 0.40, alpha: 1)
        let dark = CGColor(red: 0.035, green: 0.065, blue: 0.115, alpha: 1)
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: [lit, mid, dark] as CFArray,
                                     locations: [0, 0.42, 1]) {
            context.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: half - radius * 0.35, y: half + radius * 0.35),
                startRadius: 0,
                endCenter: CGPoint(x: half + radius * 0.12, y: half - radius * 0.14),
                endRadius: radius * 1.48,
                options: [.drawsAfterEndLocation]
            )
        }

        // Broad mineral patches break up the smooth gradient.
        let patches = max(16, Int(radius * 0.72))
        for _ in 0..<patches {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = sqrt(CGFloat.random(in: 0...1)) * radius * 0.88
            let patchRadius = CGFloat.random(in: 2...max(3, radius * 0.23))
            let lightPatch = Bool.random()
            context.setFillColor(CGColor(
                red: lightPatch ? 0.56 : 0.02,
                green: lightPatch ? 0.71 : 0.035,
                blue: lightPatch ? 0.77 : 0.065,
                alpha: lightPatch ? 0.10 : 0.16
            ))
            context.fillEllipse(in: CGRect(
                x: half + cos(angle) * distance - patchRadius,
                y: half + sin(angle) * distance - patchRadius,
                width: patchRadius * 2.3, height: patchRadius * 1.4
            ))
        }

        // Small flecks and surface grit; rendered once, not per frame.
        let grains = min(1500, max(140, Int(radius * radius * 0.23)))
        for _ in 0..<grains {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = sqrt(CGFloat.random(in: 0...1)) * radius
            let x = half + cos(angle) * distance
            let y = half + sin(angle) * distance
            let lightGrain = Bool.random()
            let alpha = CGFloat.random(in: 0.08...0.32)
            context.setFillColor(CGColor(
                red: lightGrain ? 0.75 : 0.025,
                green: lightGrain ? 0.87 : 0.05,
                blue: lightGrain ? 0.90 : 0.08, alpha: alpha
            ))
            let grain = CGFloat.random(in: 0.45...1.9)
            context.fill(CGRect(x: x, y: y, width: grain, height: grain))
        }

        // Raised ridges and shadowed fissures create depth independent of
        // the vector outline and rotate along with the asteroid.
        for _ in 0..<max(6, Int(radius / 6)) {
            let phi = CGFloat.random(in: 0...(2 * .pi))
            let reach = radius * CGFloat.random(in: 0.16...0.55)
            let start = CGPoint(
                x: half + cos(phi) * reach * 0.3,
                y: half + sin(phi) * reach * 0.3
            )
            let end = CGPoint(
                x: start.x + cos(phi + 0.38) * reach,
                y: start.y + sin(phi + 0.38) * reach
            )
            let groove = CGMutablePath()
            groove.move(to: start)
            groove.addLine(to: end)
            context.addPath(groove)
            context.setStrokeColor(CGColor(red: 0.015, green: 0.04, blue: 0.07, alpha: 0.55))
            context.setLineWidth(CGFloat.random(in: 1.0...3.2))
            context.strokePath()
            context.addPath(groove)
            context.translateBy(x: -1, y: 1)
            context.setStrokeColor(CGColor(red: 0.68, green: 0.84, blue: 0.87, alpha: 0.24))
            context.setLineWidth(0.8)
            context.strokePath()
            context.translateBy(x: 1, y: -1)
        }

        // Each crater has a shadowed basin and an off-center illuminated rim.
        let craterCount = max(2, Int(radius / 13))
        for _ in 0..<craterCount {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 0...0.57) * radius
            let x = half + cos(angle) * distance
            let y = half + sin(angle) * distance
            let cr = CGFloat.random(in: 2.5...max(4, radius * 0.16))
            let bounds = CGRect(x: x - cr, y: y - cr * 0.68,
                                width: cr * 2, height: cr * 1.36)
            context.setFillColor(CGColor(red: 0.012, green: 0.025, blue: 0.055, alpha: 0.80))
            context.fillEllipse(in: bounds)
            context.setStrokeColor(CGColor(red: 0.77, green: 0.91, blue: 0.97, alpha: 0.53))
            context.setLineWidth(1.4)
            context.strokeEllipse(in: bounds.offsetBy(dx: -0.9, dy: 1.2))
            context.setStrokeColor(CGColor(red: 0.015, green: 0.04, blue: 0.09, alpha: 0.85))
            context.strokeEllipse(in: bounds.offsetBy(dx: 1, dy: -1))
        }

        context.restoreGState()
        // Cool rim light follows the silhouette while the body is opaque.
        context.addPath(silhouette)
        context.setLineWidth(2.0)
        context.setStrokeColor(CGColor(red: 0.59, green: 0.82, blue: 0.89, alpha: 0.88))
        context.strokePath()

        guard let image = context.makeImage() else { return SKSpriteNode() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = CGSize(width: CGFloat(side), height: CGFloat(side))
        sprite.zPosition = -1
        sprite.isHidden = true
        return sprite
    }
}
