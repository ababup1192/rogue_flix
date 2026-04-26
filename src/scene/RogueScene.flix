// RogueScene — scene integration: assembles floors, walls, and player into a unified scene

mod RogueScene {
    pub def rootName(): String = "Root"

    // ========================================================================
    // Scene Building
    // ========================================================================

    pub def buildInitialScene(
        cols: Int32, rows: Int32,
        playerGridX: Int32, playerGridY: Int32,
        tileSz: Float32, moveSpd: Float32
    ): SceneTree.Node =
        let floorTiles = FloorScene.buildFloorTiles(cols, rows, tileSz);
        let wallTiles = WallScene.buildWallTiles(cols, rows, tileSz);
        let floors = SceneTree.node2D("Floors", Vec2D.zero(), floorTiles);
        let walls = SceneTree.node2D("Walls", Vec2D.zero(), wallTiles);
        let player = PlayerScene.buildPlayer(playerGridX, playerGridY, tileSz, moveSpd);
        SceneTree.node2D(rootName(), Vec2D.zero(),
            floors :: walls :: player :: Nil
        )

    // ========================================================================
    // Physics
    // ========================================================================

    pub def stepPhysics(dt: Float32, scene: SceneTree.Node): SceneTree.Node =
        SceneTree.stepCharacterBodies(dt, scene)
}
