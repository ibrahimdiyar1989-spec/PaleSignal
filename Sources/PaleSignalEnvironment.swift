import SceneKit
import UIKit
import CoreImage

/// Runtime AAA material, environment, lighting, and particle utilities.
/// The repository is intentionally generated without external binary dependencies.
enum PaleSignalEnvironment {
    static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    static func configureCamera(_ camera: SCNCamera) {
        camera.wantsHDR = true
        camera.screenSpaceAmbientOcclusionIntensity = 1.4
        camera.screenSpaceAmbientOcclusionRadius = 1.8
        camera.wantsDepthOfField = true
        camera.fStop = 1.8
        camera.filmGrainIntensity = 0.04
        camera.colorFringeIntensity = 0.015
        camera.wantsExposureAdaptation = true
        camera.bloomIntensity = 0.42
        camera.vignettingIntensity = 1.0
        camera.saturation = 0.72
        camera.contrast = 1.22
        camera.zNear = 0.1
        camera.zFar = 80
    }

    static func pbrMaterial(name: String, base: UIColor, roughness: Float, metalness: Float = 0) -> SCNMaterial {
        let material = SCNMaterial()
        material.name = name
        material.diffuse.contents = base
        material.roughness.contents = CGFloat(roughness)
        material.metalness.contents = CGFloat(metalness)
        material.normal.contents = normalMap(name: name)
        material.displacement.contents = grimeMap(name: name)
        material.lightingModel = .physicallyBased
        material.isDoubleSided = false
        material.roughness.intensity = 1
        return material
    }

    static func woodMaterial() -> SCNMaterial {
        pbrMaterial(name: "weathered wood", base: UIColor(red: 0.27, green: 0.19, blue: 0.12, alpha: 1), roughness: 0.82)
    }

    static func concreteMaterial() -> SCNMaterial {
        pbrMaterial(name: "damp concrete", base: UIColor(red: 0.22, green: 0.23, blue: 0.24, alpha: 1), roughness: 0.76)
    }

    static func ironMaterial() -> SCNMaterial {
        pbrMaterial(name: "rusted iron", base: UIColor(red: 0.26, green: 0.20, blue: 0.16, alpha: 1), roughness: 0.58, metalness: 0.82)
    }

    static func wetTileMaterial() -> SCNMaterial {
        let m = pbrMaterial(name: "wet tile", base: UIColor(red: 0.12, green: 0.15, blue: 0.17, alpha: 1), roughness: 0.10, metalness: 0.88)
        m.normal.contents = waterNormalMap()
        m.diffuse.contents = UIColor(red: 0.08, green: 0.12, blue: 0.14, alpha: 1)
        m.transparent.contents = UIColor(white: 0.75, alpha: 0.30)
        m.blendMode = .alpha
        return m
    }

    static func normalMap(name: String) -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let seed = Float(name.unicodeScalars.reduce(0) { $0 + UInt32($1.value) })
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(red: 0.5, green: 0.5, blue: 1, alpha: 1)
            c.fill(CGRect(origin: .zero, size: size))
            for y in stride(from: 0, to: Int(size.height), by: 4) {
                for x in stride(from: 0, to: Int(size.width), by: 4) {
                    let sx = sin(Float(x) * 0.037 + seed)
                    let sy = cos(Float(y) * 0.053 + seed * 0.5)
                    c.setFillColor(red: CGFloat(0.47 + 0.05 * sx), green: CGFloat(0.47 + 0.05 * sy), blue: 0.92, alpha: 1)
                    c.fill(CGRect(x: x, y: y, width: 4, height: 4))
                }
            }
        }
    }

    static func grimeMap(name: String) -> UIImage {
        let size = CGSize(width: 512, height: 512)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            ctx.cgContext.setFillColor(UIColor(red: 0.15, green: 0.14, blue: 0.13, alpha: 1).cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
            for _ in 0..<900 {
                let r = CGFloat.random(in: 0.5...5)
                let p = CGPoint(x: CGFloat.random(in: 0...512), y: CGFloat.random(in: 0...512))
                ctx.cgContext.setFillColor(UIColor(white: CGFloat.random(in: 0.05...0.32), alpha: CGFloat.random(in: 0.15...0.65)).cgColor)
                ctx.cgContext.fillEllipse(in: CGRect(x: p.x-r, y: p.y-r, width: r*2, height: r*2))
            }
        }
    }

    static func waterNormalMap() -> UIImage {
        let size = CGSize(width: 512, height: 512)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(red: 0.48, green: 0.50, blue: 0.88, alpha: 1)
            c.fill(CGRect(origin: .zero, size: size))
            for y in stride(from: 0, to: 512, by: 8) {
                c.setStrokeColor(red: 0.62, green: 0.64, blue: 1.0, alpha: 0.34)
                c.move(to: CGPoint(x: 0, y: CGFloat(y)))
                c.addCurve(to: CGPoint(x: 512, y: CGFloat(y)), control1: CGPoint(x: 170, y: CGFloat(y+20)), control2: CGPoint(x: 340, y: CGFloat(y-20)))
                c.strokePath()
            }
        }
    }

    static func configureShadow(_ light: SCNLight) {
        light.shadowMode = .deferred
        light.shadowMapSize = CGSize(width: 2048, height: 2048)
        light.shadowSampleCount = 16
        light.shadowRadius = 2.2
        light.shadowColor = UIColor(red: 0.015, green: 0.020, blue: 0.030, alpha: 0.88)
    }

    static func addMoonlightShaft(to world: SCNNode, position: SCNVector3) {
        let cone = SCNCone(topRadius: 0.18, bottomRadius: 3.8, height: 12)
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.52, green: 0.62, blue: 0.72, alpha: 0.055)
        m.emission.contents = UIColor(red: 0.28, green: 0.36, blue: 0.44, alpha: 0.09)
        m.transparencyMode = .dualLayer
        m.isDoubleSided = true
        m.blendingMode = .additive
        m.writesToDepthBuffer = false
        cone.materials = [m]
        let shaft = SCNNode(geometry: cone)
        shaft.position = position
        shaft.eulerAngles.z = -.pi / 2
        world.addChildNode(shaft)
    }

    static func addDust(to node: SCNNode) {
        let particles = SCNParticleSystem()
        particles.birthRate = 22
        particles.lifeSpan = 7
        particles.lifeSpanVariation = 3
        particles.particleSize = 0.018
        particles.particleIntensity = 0.30
        particles.particleColor = UIColor(red: 0.68, green: 0.72, blue: 0.74, alpha: 0.42)
        particles.particleAngleVariation = .pi
        particles.particleVelocity = 0.12
        particles.particleVelocityVariation = 0.08
        particles.emitterShape = SCNBox(width: 28, height: 12, length: 8, chamferRadius: 0)
        particles.blendingMode = .alpha
        particles.sortingMode = .distance
        node.addParticleSystem(particles)
    }

    static func addCratePhysics(to node: SCNNode, size: Float) {
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: SCNBox(width: CGFloat(size), height: CGFloat(size), length: CGFloat(size), chamferRadius: 0.05)))
        node.physicsBody?.mass = 85
        node.physicsBody?.friction = 0.90
        node.physicsBody?.damping = 0.65
        node.physicsBody?.angularDamping = 0.82
        node.physicsBody?.angularVelocityFactor = SCNVector3(0.15, 0.15, 0.15)
        node.physicsBody?.allowsResting = true
    }

    static func addWaterRipples(to world: SCNNode, at position: SCNVector3) {
        for i in 0..<2 {
            let torus = SCNTorus(ringRadius: 0.12 + CGFloat(i) * 0.10, pipeRadius: 0.012)
            let m = SCNMaterial()
            m.diffuse.contents = UIColor(red: 0.52, green: 0.68, blue: 0.74, alpha: 0.55)
            m.emission.contents = UIColor(red: 0.18, green: 0.30, blue: 0.34, alpha: 0.30)
            m.blendingMode = .alpha
            torus.materials = [m]
            let n = SCNNode(geometry: torus)
            n.position = position
            n.eulerAngles.x = -.pi / 2
            world.addChildNode(n)
            n.runAction(.sequence([.group([.scaleTo(SCNVector3(5, 5, 5), duration: 0.72), .fadeOut(duration: 0.72)]), .removeFromParentNode()]))
        }
    }
}
