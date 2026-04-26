// RogueScene — scene integration: assembles floors, walls, and player into a unified scene

mod RogueScene {
    pub def rootName(): String = "Root"

    // ========================================================================
    // Scene Building
    // ========================================================================

    pub def buildInitialScene(
        cols: Int32, rows: Int32,
        playerGridX: Int32, playerGridY: Int32,
        tileSz: Float32, moveSpd: Float32,
        floors: Set[(Int32, Int32)]
    ): SceneTree.Node =
        let floorTiles = FloorScene.buildFloorTiles(floors, cols, rows, tileSz);
        let wallTiles = WallScene.buildWallTiles(floors, cols, rows, tileSz);
        let floorGroup = SceneTree.node2D("Floors", Vec2D.zero(), floorTiles);
        let wallGroup = SceneTree.node2D("Walls", Vec2D.zero(), wallTiles);
        let player = PlayerScene.buildPlayer(playerGridX, playerGridY, tileSz, moveSpd);
        SceneTree.node2D(rootName(), Vec2D.zero(),
            floorGroup :: wallGroup :: player :: Nil
        )

    // ========================================================================
    // Physics
    // ========================================================================

    pub def stepPhysics(dt: Float32, scene: SceneTree.Node): SceneTree.Node =
        SceneTree.stepCharacterBodies(dt, scene)
}
