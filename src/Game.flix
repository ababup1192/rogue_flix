// Game module — types, effects, constants, and game logic for rogue

mod Game {
    import java.lang.System

    pub type alias Vec3 = {r = Float32, g = Float32, b = Float32}

    pub type alias GameState = {
        scene = SceneTree.Node
    }

    pub type alias TextureRegistry = Map[String, Int32]

    pub eff Game {
        def getInitialState(): GameState
        def render(scene: SceneTree.Node): Unit
        def shouldClose(): Bool
        def getDeltaTime(): Float32
        def isKeyPressed(keyCode: Int32): Bool
    }

    // ========================================================================
    // Constants
    // ========================================================================

    pub def screenWidth(): Int32 = 800
    pub def screenHeight(): Int32 = 600
    pub def tileSize(): Float32 = 32.0f32
    pub def gridCols(): Int32 = 25
    pub def gridRows(): Int32 = 19
    pub def moveSpeed(): Float32 = 192.0f32

    // WASD keys
    pub def keyW(): Int32 = 87
    pub def keyA(): Int32 = 65
    pub def keyS(): Int32 = 83
    pub def keyD(): Int32 = 68
    // Arrow keys
    pub def keyUp(): Int32 = 265
    pub def keyDown(): Int32 = 264
    pub def keyLeft(): Int32 = 263
    pub def keyRight(): Int32 = 262

    // ========================================================================
    // Texture Manifest
    // ========================================================================

    pub def textureManifest(): List[(String, String, Bool)] =
        ("npc", "textures/npc.png", true) ::
        ("floor", "textures/atlas_floor-16x16.png", true) ::
        ("wall", "textures/atlas_walls_low-16x16.png", true) ::
        Nil

    // ========================================================================
    // Game Initialization
    // ========================================================================

    pub def initGame(_playerRow: Int32, _playerCol: Int32): GameState \ IO =
        let seed = System.nanoTime();
        let floors = Dungeon.generate(gridCols(), gridRows(), seed);
        let start = Dungeon.playerStartForRooms(gridCols(), gridRows(), seed);
        {
            scene = RogueScene.buildInitialScene(
                gridCols(), gridRows(), start#col, start#row,
                tileSize(), moveSpeed(), floors)
        }

    /// Build game state from a pre-built floor set (for tests).
    pub def initGameWithFloors(floors: Set[(Int32, Int32)], playerRow: Int32, playerCol: Int32): GameState =
        {
            scene = RogueScene.buildInitialScene(
                gridCols(), gridRows(), playerCol, playerRow,
                tileSize(), moveSpeed(), floors)
        }

    // ========================================================================
    // Game Loop
    // ========================================================================

    pub def startGame(): GameState \ Game =
        let state = Game.getInitialState();
        runLoop(state)

    @Tailrec
    def runLoop(state: GameState): GameState \ Game =
        if (Game.shouldClose()) state
        else {
            let newState = updateGame(state);
            Game.render(newState#scene);
            runLoop(newState)
        }

    // ========================================================================
    // Game Logic — per-frame update
    // ========================================================================

    pub def updateGame(state: GameState): GameState \ Game =
        let dt = Game.getDeltaTime();
        {scene = state#scene
            |> processInput
            |> RogueScene.stepPhysics(dt)}

    def processInput(scene: SceneTree.Node): SceneTree.Node \ Game =
        if (PlayerScene.isPlayerMoving(scene)) scene
        else {
            let up = Game.isKeyPressed(keyW()) or Game.isKeyPressed(keyUp());
            let down = Game.isKeyPressed(keyS()) or Game.isKeyPressed(keyDown());
            let left = Game.isKeyPressed(keyA()) or Game.isKeyPressed(keyLeft());
            let right = Game.isKeyPressed(keyD()) or Game.isKeyPressed(keyRight());
            let ts = tileSize();
            if (up) PlayerScene.movePlayer(SceneTree.Direction.Up, ts, scene)
            else if (down) PlayerScene.movePlayer(SceneTree.Direction.Down, ts, scene)
            else if (left) PlayerScene.movePlayer(SceneTree.Direction.Left, ts, scene)
            else if (right) PlayerScene.movePlayer(SceneTree.Direction.Right, ts, scene)
            else scene
        }
}
