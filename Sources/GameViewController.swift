import UIKit
import SceneKit
import simd

final class GameViewController: UIViewController, SCNSceneRendererDelegate, TouchControlDelegate {
    private var scnView = SCNView()
    private let scene = SCNScene()
    private let world = SCNNode()
    private var cameraNode = SCNNode()
    private var playerNode = SCNNode()
    private var playerLight: SCNLight?
    private var playerCone: SCNNode?
    private let controls = TouchControlOverlay()
    private let menu = UIView()
    private let statusLabel = UILabel()
    private let titleLabel = UILabel()
    private let levelLabel = UILabel()
    private let meter = UIView()
    private var meterWidth: NSLayoutConstraint?

    private var levelIndex = 0
    private var level: LevelDefinition { LevelCatalog.all[levelIndex] }
    private var state: State = .menu
    private enum State { case menu, playing }
    private var playerPosition = SIMD2<Float>(0, 1)
    private var playerVelocity = SIMD2<Float>(repeating: 0)
    private var facing: Float = 1
    private var grounded = false
    private var crouched = false
    private var flashlightOn = true
    private var leftHeld = false
    private var rightHeld = false
    private var crouchHeld = false
    private var pushHeld = false
    private var jumpQueued = false
    private var elapsed: Float = 0
    private var lastTime: TimeInterval = 0
    private var detection: Float = 0
    private var darknessY: Float = -20

    private struct RuntimeBlock {
        let definition: LevelBlock
        let node: SCNNode
        var center: SIMD2<Float>
    }
    private struct RuntimeCrate {
        let node: SCNNode
        var position: SIMD2<Float>
        var velocity: SIMD2<Float>
        let half: Float
    }
    private struct RuntimeEnemy {
        let definition: EnemyDef
        let node: SCNNode
        var position: SIMD2<Float>
        var direction: Float
    }
    private struct RuntimeSpotlight {
        let definition: SpotlightDef
        let pivot: SCNNode
    }
    private var blocks: [RuntimeBlock] = []
    private var crates: [RuntimeCrate] = []
    private var enemies: [RuntimeEnemy] = []
    private var spotlights: [RuntimeSpotlight] = []
    private var exitNode: SCNNode?
    private var darknessNode: SCNNode?

    private let standing = SIMD2<Float>(0.32, 0.72)
    private let ducking = SIMD2<Float>(0.32, 0.39)

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupScene()
        setupInterface()
        loadLevel(0, play: false)
    }

    private func setupScene() {
        scnView = SCNView(frame: view.bounds)
        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scnView.preferredFramesPerSecond = 60
        scnView.antialiasingMode = .none
        scnView.rendersContinuously = true
        scnView.delegate = self
        scnView.scene = scene
        scnView.backgroundColor = UIColor(red: 0.018, green: 0.025, blue: 0.04, alpha: 1)
        view.addSubview(scnView)
        scene.fogStartDistance = 13
        scene.fogEndDistance = 38
        scene.fogColor = UIColor(red: 0.025, green: 0.035, blue: 0.05, alpha: 1)
        scene.rootNode.addChildNode(world)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 260
        ambient.color = UIColor(red: 0.25, green: 0.30, blue: 0.40, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let camera = SCNCamera()
        camera.fieldOfView = 42
        camera.zNear = 0.1
        camera.zFar = 80
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 2.5, 15)
        scene.rootNode.addChildNode(cameraNode)
        scnView.pointOfView = cameraNode
    }

    private func setupInterface() {
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.delegate = self
        view.addSubview(controls)
        NSLayoutConstraint.activate([
            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controls.topAnchor.constraint(equalTo: view.topAnchor),
            controls.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let hud = UIView()
        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.isUserInteractionEnabled = false
        view.addSubview(hud)
        levelLabel.translatesAutoresizingMaskIntoConstraints = false
        levelLabel.font = .monospacedSystemFont(ofSize: 13, weight: .bold)
        levelLabel.textColor = UIColor(white: 0.86, alpha: 0.92)
        hud.addSubview(levelLabel)
        let meterBack = UIView()
        meterBack.translatesAutoresizingMaskIntoConstraints = false
        meterBack.backgroundColor = UIColor(white: 0.12, alpha: 0.8)
        meterBack.layer.cornerRadius = 4
        hud.addSubview(meterBack)
        meter.translatesAutoresizingMaskIntoConstraints = false
        meter.backgroundColor = UIColor(red: 0.8, green: 0.18, blue: 0.2, alpha: 0.95)
        meter.layer.cornerRadius = 3
        meterBack.addSubview(meter)
        meterWidth = meter.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            hud.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            hud.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            levelLabel.topAnchor.constraint(equalTo: hud.topAnchor),
            levelLabel.leadingAnchor.constraint(equalTo: hud.leadingAnchor),
            meterBack.topAnchor.constraint(equalTo: levelLabel.bottomAnchor, constant: 5),
            meterBack.leadingAnchor.constraint(equalTo: levelLabel.leadingAnchor),
            meterBack.widthAnchor.constraint(equalToConstant: 130),
            meterBack.heightAnchor.constraint(equalToConstant: 8),
            meter.leadingAnchor.constraint(equalTo: meterBack.leadingAnchor),
            meter.topAnchor.constraint(equalTo: meterBack.topAnchor),
            meter.bottomAnchor.constraint(equalTo: meterBack.bottomAnchor),
            meterWidth!
        ])

        menu.translatesAutoresizingMaskIntoConstraints = false
        menu.backgroundColor = UIColor(white: 0.015, alpha: 0.88)
        view.addSubview(menu)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "PALE SIGNAL"
        titleLabel.textColor = UIColor(red: 0.80, green: 0.88, blue: 0.90, alpha: 1)
        titleLabel.font = .monospacedSystemFont(ofSize: 34, weight: .light)
        titleLabel.textAlignment = .center
        menu.addSubview(titleLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = UIColor(white: 0.66, alpha: 1)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        menu.addSubview(statusLabel)
        let play = menuButton("PLAY") { [weak self] in
            guard let self else { return }
            ProceduralAudioEngine.shared.start()
            self.loadLevel(self.levelIndex, play: true)
        }
        let row = UIStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.spacing = 8
        row.distribution = .fillEqually
        menu.addSubview(row)
        for index in 0..<3 {
            let button = menuButton("LEVEL \(index + 1)") { [weak self] in
                guard let self else { return }
                ProceduralAudioEngine.shared.start()
                self.loadLevel(index, play: true)
            }
            row.addArrangedSubview(button)
        }
        let restart = menuButton("RESTART CURRENT LEVEL") { [weak self] in
            guard let self else { return }
            ProceduralAudioEngine.shared.start()
            self.loadLevel(self.levelIndex, play: true)
        }
        NSLayoutConstraint.activate([
            menu.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            menu.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            menu.topAnchor.constraint(equalTo: view.topAnchor),
            menu.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: menu.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: menu.centerYAnchor, constant: -95),
            titleLabel.widthAnchor.constraint(equalToConstant: 420),
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            statusLabel.centerXAnchor.constraint(equalTo: menu.centerXAnchor),
            statusLabel.widthAnchor.constraint(equalToConstant: 460),
            play.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 18),
            play.centerXAnchor.constraint(equalTo: menu.centerXAnchor),
            play.widthAnchor.constraint(equalToConstant: 280),
            play.heightAnchor.constraint(equalToConstant: 42),
            row.topAnchor.constraint(equalTo: play.bottomAnchor, constant: 10),
            row.centerXAnchor.constraint(equalTo: menu.centerXAnchor),
            row.widthAnchor.constraint(equalToConstant: 280),
            row.heightAnchor.constraint(equalToConstant: 38),
            restart.topAnchor.constraint(equalTo: row.bottomAnchor, constant: 10),
            restart.centerXAnchor.constraint(equalTo: menu.centerXAnchor),
            restart.widthAnchor.constraint(equalToConstant: 280),
            restart.heightAnchor.constraint(equalToConstant: 38)
        ])
        controls.isHidden = true
    }

    private func menuButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .monospacedSystemFont(ofSize: 13, weight: .bold)
        button.setTitleColor(UIColor(white: 0.92, alpha: 1), for: .normal)
        button.backgroundColor = UIColor(white: 0.14, alpha: 0.9)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(white: 0.6, alpha: 0.35).cgColor
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        menu.addSubview(button)
        return button
    }

    private func loadLevel(_ index: Int, play: Bool) {
        guard LevelCatalog.all.indices.contains(index) else { return }
        levelIndex = index
        world.childNodes.forEach { $0.removeFromParentNode() }
        blocks.removeAll(keepingCapacity: true)
        crates.removeAll(keepingCapacity: true)
        enemies.removeAll(keepingCapacity: true)
        spotlights.removeAll(keepingCapacity: true)
        exitNode = nil
        darknessNode = nil
        elapsed = 0
        detection = 0
        darknessY = level.initialDarknessY
        playerPosition = level.playerStart
        playerVelocity = .zero
        grounded = false
        crouched = false
        flashlightOn = true
        resetInputs()
        buildBackdrop()
        buildBlocks()
        buildCrates()
        buildEnemies()
        buildSpotlights()
        buildPlayer()
        buildExit()
        levelLabel.text = level.title
        statusLabel.text = level.subtitle
        menu.isHidden = play
        controls.isHidden = !play
        state = play ? .playing : .menu
        cameraNode.position = SCNVector3(playerPosition.x + 2, playerPosition.y + 2, 15)
    }

    private func buildBackdrop() {
        let wall = SCNBox(width: 80, height: 45, length: 0.5, chamferRadius: 0)
        wall.firstMaterial?.diffuse.contents = UIColor(red: 0.045, green: 0.055, blue: 0.075, alpha: 1)
        let node = SCNNode(geometry: wall)
        node.position = SCNVector3(14, 8, -4)
        world.addChildNode(node)
        if level.hasWaterHazard {
            let water = SCNBox(width: 60, height: 2.5, length: 5, chamferRadius: 0)
            water.firstMaterial?.diffuse.contents = UIColor(red: 0.025, green: 0.10, blue: 0.14, alpha: 1)
            water.firstMaterial?.roughness.contents = 0.2
            let waterNode = SCNNode(geometry: water)
            waterNode.position = SCNVector3(15, level.waterLevelY - 1.25, 0)
            world.addChildNode(waterNode)
        }
        if level.risingDarknessSpeed > 0 {
            let darkness = SCNBox(width: 18, height: 8, length: 5, chamferRadius: 0)
            darkness.firstMaterial?.diffuse.contents = UIColor(red: 0.02, green: 0.005, blue: 0.015, alpha: 1)
            darkness.firstMaterial?.emission.contents = UIColor(red: 0.12, green: 0.015, blue: 0.035, alpha: 1)
            let node = SCNNode(geometry: darkness)
            node.position = SCNVector3(2, darknessY - 4, 0.2)
            world.addChildNode(node)
            darknessNode = node
        }
    }

    private func buildBlocks() {
        for definition in level.blocks {
            let geometry = SCNBox(width: CGFloat(definition.size.x), height: CGFloat(definition.size.y), length: CGFloat(definition.depth), chamferRadius: 0.035)
            let material = SCNMaterial()
            material.diffuse.contents = definition.kind == .gearPlatform
                ? UIColor(red: 0.17, green: 0.20, blue: 0.24, alpha: 1)
                : UIColor(red: 0.22, green: 0.17, blue: 0.13, alpha: 1)
            material.roughness.contents = 0.9
            geometry.materials = [material]
            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(definition.center.x, definition.center.y, definition.zOffset)
            world.addChildNode(node)
            blocks.append(RuntimeBlock(definition: definition, node: node, center: definition.center))
            if definition.kind == .gearPlatform {
                let gear = SCNCylinder(radius: CGFloat(definition.size.x * 0.42), height: 0.18)
                gear.firstMaterial?.diffuse.contents = UIColor(white: 0.22, alpha: 1)
                let gearNode = SCNNode(geometry: gear)
                gearNode.eulerAngles.x = .pi / 2
                gearNode.position = SCNVector3(0, 0, -1.2)
                node.addChildNode(gearNode)
                gearNode.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: CGFloat.pi * 2, duration: 8)))
            }
        }
    }

    private func buildCrates() {
        for definition in level.crates {
            let geometry = SCNBox(width: CGFloat(definition.size), height: CGFloat(definition.size), length: CGFloat(definition.size), chamferRadius: 0.05)
            geometry.firstMaterial?.diffuse.contents = UIColor(red: 0.34, green: 0.23, blue: 0.13, alpha: 1)
            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(definition.x, definition.y, 0)
            world.addChildNode(node)
            crates.append(RuntimeCrate(node: node, position: SIMD2(definition.x, definition.y), velocity: .zero, half: definition.size * 0.5))
        }
    }

    private func buildEnemies() {
        for definition in level.enemies {
            let body = SCNCapsule(capRadius: definition.isCrawler ? 0.28 : 0.32, height: definition.isCrawler ? 0.7 : 1.7)
            body.firstMaterial?.diffuse.contents = UIColor(white: 0.018, alpha: 1)
            let node = SCNNode(geometry: body)
            if definition.isCrawler { node.eulerAngles.z = .pi / 2 }
            node.position = SCNVector3(definition.startX, definition.y, 0.15)
            let eye = SCNSphere(radius: 0.09)
            eye.firstMaterial?.diffuse.contents = UIColor(red: 1, green: 0.22, blue: 0.16, alpha: 1)
            eye.firstMaterial?.emission.contents = UIColor(red: 1, green: 0.08, blue: 0.03, alpha: 1)
            let eyeNode = SCNNode(geometry: eye)
            eyeNode.position = SCNVector3(0.28, 0.25, 0.25)
            node.addChildNode(eyeNode)
            world.addChildNode(node)
            enemies.append(RuntimeEnemy(definition: definition, node: node, position: SIMD2(definition.startX, definition.y), direction: 1))
        }
    }

    private func buildSpotlights() {
        for definition in level.spotlights {
            let pivot = SCNNode()
            pivot.position = SCNVector3(definition.pivotX, definition.pivotY, -0.5)
            let cone = SCNCone(topRadius: 0.12, bottomRadius: CGFloat(definition.beamHalfWidth * 1.4), height: CGFloat(max(2, definition.pivotY - definition.targetY)))
            cone.firstMaterial?.diffuse.contents = UIColor(red: 0.76, green: 0.83, blue: 0.9, alpha: 0.12)
            cone.firstMaterial?.emission.contents = UIColor(white: 0.14, alpha: 0.12)
            cone.firstMaterial?.writesToDepthBuffer = false
            let beam = SCNNode(geometry: cone)
            beam.position.y = -Float(cone.height) * 0.5
            pivot.addChildNode(beam)
            world.addChildNode(pivot)
            spotlights.append(RuntimeSpotlight(definition: definition, pivot: pivot))
        }
    }

    private func buildPlayer() {
        playerNode = SCNNode()
        let body = SCNCapsule(capRadius: 0.25, height: 1.2)
        body.firstMaterial?.diffuse.contents = UIColor(red: 0.66, green: 0.69, blue: 0.64, alpha: 1)
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position.y = -0.05
        playerNode.addChildNode(bodyNode)
        let head = SCNSphere(radius: 0.2)
        head.firstMaterial?.diffuse.contents = UIColor(white: 0.82, alpha: 1)
        let headNode = SCNNode(geometry: head)
        headNode.position = SCNVector3(0, 0.52, 0.08)
        playerNode.addChildNode(headNode)
        let light = SCNLight()
        light.type = .spot
        light.intensity = 1100
        light.spotInnerAngle = 22
        light.spotOuterAngle = 48
        light.attenuationEndDistance = 12
        light.castsShadow = false
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(0.25, 0.1, 0.2)
        playerNode.addChildNode(lightNode)
        playerLight = light
        let cone = SCNCone(topRadius: 0.04, bottomRadius: 1.0, height: 4.5)
        cone.firstMaterial?.diffuse.contents = UIColor(white: 0.9, alpha: 0.07)
        cone.firstMaterial?.emission.contents = UIColor(white: 0.5, alpha: 0.06)
        let coneNode = SCNNode(geometry: cone)
        coneNode.eulerAngles.z = -.pi / 2
        coneNode.position = SCNVector3(2.2, 0.05, 0)
        lightNode.addChildNode(coneNode)
        playerCone = coneNode
        world.addChildNode(playerNode)
        syncPlayer()
    }

    private func buildExit() {
        let portal = SCNBox(width: 1.1, height: 2.0, length: 0.2, chamferRadius: 0.04)
        portal.firstMaterial?.diffuse.contents = UIColor(red: 0.30, green: 0.75, blue: 0.72, alpha: 1)
        portal.firstMaterial?.emission.contents = UIColor(red: 0.17, green: 0.55, blue: 0.52, alpha: 1)
        let node = SCNNode(geometry: portal)
        node.position = SCNVector3(level.exitPos.x, level.exitPos.y, 0)
        world.addChildNode(node)
        exitNode = node
    }

    func controlStateChanged(action: ControlAction, isPressed: Bool) {
        switch action {
        case .left: leftHeld = isPressed
        case .right: rightHeld = isPressed
        case .crouch: crouchHeld = isPressed
        case .push: pushHeld = isPressed
        case .jump: if isPressed { jumpQueued = true }
        case .flashlight: break
        }
    }

    func controlTriggered(action: ControlAction) {
        guard state == .playing, action == .flashlight else { return }
        flashlightOn.toggle()
        playerLight?.intensity = flashlightOn ? 1100 : 0
        playerCone?.isHidden = !flashlightOn
        ProceduralAudioEngine.shared.playFlashlightClick()
    }

    private func resetInputs() {
        leftHeld = false
        rightHeld = false
        crouchHeld = false
        pushHeld = false
        jumpQueued = false
        controls.resetAll()
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard state == .playing else { lastTime = time; return }
        if lastTime == 0 { lastTime = time; return }
        let dt = Float(min(1.0 / 30.0, max(0, time - lastTime)))
        lastTime = time
        elapsed += dt
        updatePlatforms()
        updatePlayer(dt)
        updateEnemies(dt)
        updateHazards(dt)
        updateCamera(dt)
    }

    private func updatePlatforms() {
        for i in blocks.indices where blocks[i].definition.bobAmplitude > 0 {
            let d = blocks[i].definition
            let y = d.center.y + sin(elapsed * d.bobSpeed + d.bobPhase) * d.bobAmplitude
            blocks[i].center.y = y
            blocks[i].node.position.y = y
        }
    }

    private func solidBoxes() -> [AABB] {
        blocks.map { AABB(center: $0.center, halfExtents: $0.definition.size * 0.5) }
    }

    private func updatePlayer(_ dt: Float) {
        if crouchHeld { crouched = true }
        else if crouched && canStand() { crouched = false }
        let half = crouched ? ducking : standing
        let input = (rightHeld ? Float(1) : 0) - (leftHeld ? Float(1) : 0)
        if input != 0 { facing = input }
        playerVelocity.x = input * (crouched ? 2.2 : (pushHeld ? 2.8 : 4.4))
        if jumpQueued {
            if grounded && !crouched {
                playerVelocity.y = 8.0
                grounded = false
                ProceduralAudioEngine.shared.playJump()
            }
            jumpQueued = false
        }
        playerVelocity.y -= 20 * dt
        playerPosition.x += playerVelocity.x * dt
        resolveHorizontal(half)
        let oldY = playerPosition.y
        playerPosition.y += playerVelocity.y * dt
        grounded = false
        resolveVertical(half, oldY: oldY)
        syncPlayer()
        if abs(input) > 0.1 && grounded { elapsed += 0; }
    }

    private func resolveHorizontal(_ half: SIMD2<Float>) {
        let boxes = solidBoxes()
        for i in crates.indices {
            let crateBox = AABB(center: crates[i].position, halfExtents: SIMD2(repeating: crates[i].half))
            let playerBox = AABB(center: playerPosition, halfExtents: half)
            guard playerBox.intersects(crateBox) else { continue }
            let sign: Float = playerPosition.x < crates[i].position.x ? -1 : 1
            let overlap = half.x + crates[i].half - abs(playerPosition.x - crates[i].position.x)
            if pushHeld && !crouched {
                let newX = crates[i].position.x - sign * overlap
                let test = AABB(center: SIMD2(newX, crates[i].position.y), halfExtents: SIMD2(repeating: crates[i].half))
                if !boxes.contains(where: { test.intersects($0) }) {
                    crates[i].position.x = newX
                    crates[i].node.position.x = newX
                } else {
                    playerPosition.x += sign * overlap
                    playerVelocity.x = 0
                }
            } else {
                playerPosition.x += sign * overlap
                playerVelocity.x = 0
            }
        }
        for box in boxes {
            let playerBox = AABB(center: playerPosition, halfExtents: half)
            guard playerBox.intersects(box) else { continue }
            let overlap = half.x + box.halfExtents.x - abs(playerPosition.x - box.center.x)
            playerPosition.x += playerPosition.x < box.center.x ? -overlap : overlap
            playerVelocity.x = 0
        }
    }

    private func resolveVertical(_ half: SIMD2<Float>, oldY: Float) {
        for crate in crates {
            let box = AABB(center: crate.position, halfExtents: SIMD2(repeating: crate.half))
            guard AABB(center: playerPosition, halfExtents: half).intersects(box) else { continue }
            if playerPosition.y >= crate.position.y {
                playerPosition.y = crate.position.y + crate.half + half.y
                if playerVelocity.y < 0 { playerVelocity.y = 0 }
                grounded = true
            } else {
                playerPosition.y = crate.position.y - crate.half - half.y
                if playerVelocity.y > 0 { playerVelocity.y = 0 }
            }
        }
        for box in solidBoxes() {
            let current = AABB(center: playerPosition, halfExtents: half)
            guard current.intersects(box) else { continue }
            if oldY >= box.center.y {
                playerPosition.y = box.maxY + half.y
                if playerVelocity.y < 0 { playerVelocity.y = 0 }
                grounded = true
            } else {
                playerPosition.y = box.minY - half.y
                if playerVelocity.y > 0 { playerVelocity.y = 0 }
            }
        }
    }

    private func canStand() -> Bool {
        let test = AABB(center: SIMD2(playerPosition.x, playerPosition.y + standing.y - ducking.y), halfExtents: standing)
        return !solidBoxes().contains(where: { test.intersects($0) })
    }

    private func syncPlayer() {
        playerNode.position = SCNVector3(playerPosition.x, playerPosition.y, 0)
        playerNode.scale.y = crouched ? 0.58 : 1
        playerNode.eulerAngles.y = facing < 0 ? .pi : 0
    }

    private func updateEnemies(_ dt: Float) {
        var seen = false
        let visibility: Float = (crouched ? 0.45 : 1) * (flashlightOn ? 1 : 0.48)
        for i in enemies.indices {
            let e = enemies[i].definition
            enemies[i].position.x += enemies[i].direction * e.speed * dt
            if enemies[i].position.x >= e.maxX { enemies[i].position.x = e.maxX; enemies[i].direction = -1 }
            if enemies[i].position.x <= e.minX { enemies[i].position.x = e.minX; enemies[i].direction = 1 }
            enemies[i].node.position.x = enemies[i].position.x
            let dx = playerPosition.x - enemies[i].position.x
            let range: Float = dx * enemies[i].direction > 0 ? 5.2 : 1.8
            if abs(dx) < range * visibility && abs(playerPosition.y - enemies[i].position.y) < 1.5 && !sheltered() { seen = true }
        }
        for spotlight in spotlights {
            let d = spotlight.definition
            let offset = sin(elapsed * d.speed + d.phase) * d.sweepRadius
            spotlight.pivot.eulerAngles.z = atan2(offset, d.pivotY - d.targetY)
            let fraction = max(0, min(1, (d.pivotY - playerPosition.y) / max(0.1, d.pivotY - d.targetY)))
            let beamX = d.pivotX + offset * fraction
            let beamWidth = d.beamHalfWidth * (crouched && !flashlightOn ? 0.55 : 1)
            if abs(playerPosition.x - beamX) < beamWidth && playerPosition.y <= d.pivotY && !sheltered() { seen = true }
        }
        detection = seen ? min(1, detection + dt * 1.2) : max(0, detection - dt * 0.65)
        DispatchQueue.main.async { [weak self] in self?.meterWidth?.constant = 130 * CGFloat(self?.detection ?? 0) }
        if detection >= 1 { endGame("THE SHADOWS FOUND YOU") }
    }

    private func sheltered() -> Bool {
        guard crouched else { return false }
        return blocks.contains { block in
            block.definition.kind == .tableTop && abs(playerPosition.x - block.center.x) < block.definition.size.x * 0.5 && playerPosition.y < block.center.y
        }
    }

    private func updateHazards(_ dt: Float) {
        if level.hasWaterHazard && playerPosition.y < level.waterLevelY + 0.15 { endGame("SWALLOWED BY THE FLOOD"); return }
        if level.risingDarknessSpeed > 0 {
            darknessY += level.risingDarknessSpeed * dt
            darknessNode?.position.y = darknessY - 4
            if playerPosition.y < darknessY { endGame("CONSUMED BY THE ABYSS"); return }
        }
        if playerPosition.y < -8 { endGame("LOST IN THE DEPTHS"); return }
        if simd_distance(playerPosition, level.exitPos) < 1.25 { finishLevel() }
    }

    private func updateCamera(_ dt: Float) {
        let targetX = playerPosition.x + facing * 1.5
        let targetY = playerPosition.y + 1.7
        let factor = min(1, dt * 5)
        cameraNode.position.x += (targetX - cameraNode.position.x) * factor
        cameraNode.position.y += (targetY - cameraNode.position.y) * factor
    }

    private func endGame(_ message: String) {
        guard state == .playing else { return }
        state = .menu
        resetInputs()
        DispatchQueue.main.async {
            self.titleLabel.text = "SIGNAL LOST"
            self.statusLabel.text = message
            self.menu.isHidden = false
            self.controls.isHidden = true
        }
    }

    private func finishLevel() {
        guard state == .playing else { return }
        state = .menu
        resetInputs()
        DispatchQueue.main.async {
            self.titleLabel.text = self.levelIndex == LevelCatalog.all.count - 1 ? "BEACON SILENCED" : "SECTOR CLEARED"
            self.statusLabel.text = self.levelIndex == LevelCatalog.all.count - 1 ? "The Pale Signal is silent." : "Choose the next level or continue exploring."
            self.menu.isHidden = false
            self.controls.isHidden = true
        }
    }
}
