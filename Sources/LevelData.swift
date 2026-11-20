import Foundation
import simd

struct AABB {
    var center: SIMD2<Float>
    var halfExtents: SIMD2<Float>

    var minX: Float { center.x - halfExtents.x }
    var maxX: Float { center.x + halfExtents.x }
    var minY: Float { center.y - halfExtents.y }
    var maxY: Float { center.y + halfExtents.y }

    func intersects(_ other: AABB) -> Bool {
        return abs(center.x - other.center.x) < (halfExtents.x + other.halfExtents.x) &&
               abs(center.y - other.center.y) < (halfExtents.y + other.halfExtents.y)
    }
}

enum BlockKind {
    case floor
    case tableTop
    case tableLeg
    case wall
    case gearPlatform
    case floatingDebris
}

struct LevelBlock {
    let center: SIMD2<Float>
    let size: SIMD2<Float>
    let depth: Float
    let zOffset: Float
    let kind: BlockKind
    let bobAmplitude: Float
    let bobSpeed: Float
    let bobPhase: Float

    init(
        x: Float, y: Float, w: Float, h: Float,
        depth: Float = 3.2, zOffset: Float = 0.0,
        kind: BlockKind = .floor,
        bobAmplitude: Float = 0.0, bobSpeed: Float = 0.0, bobPhase: Float = 0.0
    ) {
        self.center = SIMD2<Float>(x, y)
        self.size = SIMD2<Float>(w, h)
        self.depth = depth
        self.zOffset = zOffset
        self.kind = kind
        self.bobAmplitude = bobAmplitude
        self.bobSpeed = bobSpeed
        self.bobPhase = bobPhase
    }
}

struct CrateDef {
    let x: Float
    let y: Float
    let size: Float
}

struct EnemyDef {
    let startX: Float
    let y: Float
    let minX: Float
    let maxX: Float
    let speed: Float
    let isCrawler: Bool
}

struct SpotlightDef {
    let pivotX: Float
    let pivotY: Float
    let targetY: Float
    let sweepRadius: Float
    let speed: Float
    let phase: Float
    let beamHalfWidth: Float
}

struct LevelDefinition {
    let index: Int
    let title: String
    let subtitle: String
    let playerStart: SIMD2<Float>
    let exitPos: SIMD2<Float>
    let blocks: [LevelBlock]
    let crates: [CrateDef]
    let enemies: [EnemyDef]
    let spotlights: [SpotlightDef]
    let hasWaterHazard: Bool
    let waterLevelY: Float
    let risingDarknessSpeed: Float
    let initialDarknessY: Float
}

enum LevelCatalog {
    static let all: [LevelDefinition] = [
        level1Attics(),
        level2FloodedHall(),
        level3SignalTower()
    ]

    static func level1Attics() -> LevelDefinition {
        let blocks: [LevelBlock] = [
            LevelBlock(x: 14.0, y: -0.5, w: 36.0, h: 1.0, depth: 4.5, kind: .floor),
            LevelBlock(x: -3.5, y: 4.0, w: 1.0, h: 10.0, depth: 4.5, kind: .wall),
            LevelBlock(x: 31.5, y: 4.0, w: 1.0, h: 10.0, depth: 4.5, kind: .wall),

            // Giant Workbench (requires pushing the wooden crate to climb onto)
            LevelBlock(x: 11.5, y: 2.05, w: 5.5, h: 0.35, depth: 3.4, kind: .tableTop),
            LevelBlock(x: 9.2, y: 0.95, w: 0.35, h: 1.9, depth: 0.4, zOffset: -1.1, kind: .tableLeg),
            LevelBlock(x: 13.8, y: 0.95, w: 0.35, h: 1.9, depth: 0.4, zOffset: -1.1, kind: .tableLeg),

            // Low Table with Crawlspace Underneath
            LevelBlock(x: 20.5, y: 1.32, w: 5.2, h: 0.32, depth: 3.4, kind: .tableTop),
            LevelBlock(x: 18.2, y: 0.58, w: 0.35, h: 1.16, depth: 0.4, zOffset: -1.1, kind: .tableLeg),
            LevelBlock(x: 22.8, y: 0.58, w: 0.35, h: 1.16, depth: 0.4, zOffset: -1.1, kind: .tableLeg),

            // Exit Ledge
            LevelBlock(x: 28.0, y: 1.2, w: 4.5, h: 0.4, depth: 3.6, kind: .floor)
        ]

        return LevelDefinition(
            index: 0,
            title: "I. THE ATTICS",
            subtitle: "Push the crate to reach the workbench. Crouch under tables to stay unseen.",
            playerStart: SIMD2<Float>(0.0, 0.8),
            exitPos: SIMD2<Float>(28.8, 2.25),
            blocks: blocks,
            crates: [
                CrateDef(x: 5.5, y: 0.6, size: 1.15)
            ],
            enemies: [
                EnemyDef(startX: 23.0, y: 0.85, minX: 16.5, maxX: 25.0, speed: 2.1, isCrawler: false)
            ],
            spotlights: [
                SpotlightDef(pivotX: 11.5, pivotY: 6.5, targetY: 2.2, sweepRadius: 3.2, speed: 1.3, phase: 0.0, beamHalfWidth: 0.95)
            ],
            hasWaterHazard: false,
            waterLevelY: -10.0,
            risingDarknessSpeed: 0.0,
            initialDarknessY: -20.0
        )
    }

    static func level2FloodedHall() -> LevelDefinition {
        let blocks: [LevelBlock] = [
            LevelBlock(x: 1.0, y: -0.5, w: 6.0, h: 1.0, depth: 4.0, kind: .floor),
            LevelBlock(x: -2.0, y: 4.0, w: 1.0, h: 10.0, depth: 4.5, kind: .wall),

            LevelBlock(x: 6.2, y: -0.25, w: 2.4, h: 0.35, depth: 2.8, kind: .floatingDebris, bobAmplitude: 0.14, bobSpeed: 2.1, bobPhase: 0.0),
            LevelBlock(x: 10.2, y: 0.05, w: 2.5, h: 0.35, depth: 2.8, kind: .floatingDebris, bobAmplitude: 0.16, bobSpeed: 1.8, bobPhase: 1.3),

            LevelBlock(x: 16.5, y: -0.4, w: 7.0, h: 0.8, depth: 4.0, kind: .floor),
            LevelBlock(x: 16.5, y: 1.25, w: 3.4, h: 0.28, depth: 3.2, kind: .tableTop),
            LevelBlock(x: 15.0, y: 0.55, w: 0.3, h: 1.1, depth: 0.4, zOffset: -1.1, kind: .tableLeg),
            LevelBlock(x: 18.0, y: 0.55, w: 0.3, h: 1.1, depth: 0.4, zOffset: -1.1, kind: .tableLeg),

            LevelBlock(x: 22.4, y: -0.15, w: 2.4, h: 0.35, depth: 2.8, kind: .floatingDebris, bobAmplitude: 0.15, bobSpeed: 2.3, bobPhase: 2.2),
            LevelBlock(x: 26.2, y: 0.25, w: 2.4, h: 0.35, depth: 2.8, kind: .floatingDebris, bobAmplitude: 0.14, bobSpeed: 1.9, bobPhase: 0.7),

            LevelBlock(x: 31.2, y: 0.2, w: 5.0, h: 1.2, depth: 4.0, kind: .floor),
            LevelBlock(x: 34.0, y: 4.0, w: 1.0, h: 10.0, depth: 4.5, kind: .wall)
        ]

        return LevelDefinition(
            index: 1,
            title: "II. THE FLOODED HALL",
            subtitle: "Cross the black water. Dim your light when searchlights sweep overhead.",
            playerStart: SIMD2<Float>(0.2, 0.8),
            exitPos: SIMD2<Float>(32.0, 1.65),
            blocks: blocks,
            crates: [],
            enemies: [
                EnemyDef(startX: 18.5, y: 0.45, minX: 13.5, maxX: 19.6, speed: 2.6, isCrawler: true)
            ],
            spotlights: [
                SpotlightDef(pivotX: 8.2, pivotY: 6.2, targetY: 0.0, sweepRadius: 3.6, speed: 1.45, phase: 0.2, beamHalfWidth: 0.95),
                SpotlightDef(pivotX: 24.3, pivotY: 6.4, targetY: 0.1, sweepRadius: 3.5, speed: 1.65, phase: 2.4, beamHalfWidth: 0.95)
            ],
            hasWaterHazard: true,
            waterLevelY: -0.75,
            risingDarknessSpeed: 0.0,
            initialDarknessY: -20.0
        )
    }

    static func level3SignalTower() -> LevelDefinition {
        let blocks: [LevelBlock] = [
            LevelBlock(x: 2.0, y: -0.5, w: 10.0, h: 1.0, depth: 4.2, kind: .floor),
            LevelBlock(x: -3.2, y: 10.0, w: 1.0, h: 24.0, depth: 4.5, kind: .wall),
            LevelBlock(x: 8.2, y: 10.0, w: 1.0, h: 24.0, depth: 4.5, kind: .wall),

            LevelBlock(x: 4.8, y: 1.3, w: 3.2, h: 0.4, depth: 3.0, kind: .gearPlatform),
            LevelBlock(x: 0.2, y: 3.1, w: 3.4, h: 0.4, depth: 3.0, kind: .gearPlatform),
            LevelBlock(x: 4.6, y: 4.9, w: 3.2, h: 0.4, depth: 3.0, kind: .gearPlatform),
            LevelBlock(x: 0.4, y: 6.8, w: 3.6, h: 0.4, depth: 3.2, kind: .tableTop),
            LevelBlock(x: 4.8, y: 8.7, w: 3.2, h: 0.4, depth: 3.0, kind: .gearPlatform),
            LevelBlock(x: 0.3, y: 10.6, w: 3.4, h: 0.4, depth: 3.0, kind: .gearPlatform),
            LevelBlock(x: 4.5, y: 12.5, w: 3.4, h: 0.4, depth: 3.0, kind: .gearPlatform),

            LevelBlock(x: 2.5, y: 14.4, w: 9.8, h: 0.6, depth: 4.2, kind: .floor)
        ]

        return LevelDefinition(
            index: 2,
            title: "III. THE SIGNAL TOWER",
            subtitle: "Ascend the gears before the abyss consumes the shaft. Shut off the pale beacon.",
            playerStart: SIMD2<Float>(0.0, 0.8),
            exitPos: SIMD2<Float>(2.5, 15.65),
            blocks: blocks,
            crates: [],
            enemies: [
                EnemyDef(startX: 1.5, y: 7.55, minX: -1.1, maxX: 1.9, speed: 1.8, isCrawler: true),
                EnemyDef(startX: 4.2, y: 15.5, minX: -1.5, maxX: 6.5, speed: 2.3, isCrawler: false)
            ],
            spotlights: [
                SpotlightDef(pivotX: 2.5, pivotY: 18.8, targetY: 14.7, sweepRadius: 3.8, speed: 1.55, phase: 0.8, beamHalfWidth: 0.90)
            ],
            hasWaterHazard: false,
            waterLevelY: -10.0,
            risingDarknessSpeed: 0.72,
            initialDarknessY: -4.5
        )
    }
}
