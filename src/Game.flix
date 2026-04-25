// Game module — types, effects, constants, and game logic for rogue

mod Game {
    pub type alias Vec3 = {r = Float32, g = Float32, b = Float32}

    pub type alias GameState = {
        scene = SceneTree.Node,
        playerGridX = Int32,
        playerGridY = Int32,
        facing = SceneTree.Direction,
        currentPos = Vec2D.Vec2,
        targetPos = Vec2D.Vec2
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
    pub def gridCols(): Int32 = 20
    pub def gridRows(): Int32 = 18
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

    pub def initGame(_width: Int32, _height: Int32): GameState =
        let startX = 4;
        let startY = 4;
        let startPos = {x = Int32.toFloat32(startX) * tileSize(), y = Int32.toFloat32(startY) * tileSize()};
        let scene = RogueScene.buildInitialScene(gridCols(), gridRows(), startX, startY, tileSize());
        {
            scene = scene,
            playerGridX = startX,
            playerGridY = startY,
            facing = SceneTree.Direction.Down,
            currentPos = startPos,
            targetPos = startPos
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

    def updateGame(state: GameState): GameState \ Game =
        let dt = Game.getDeltaTime();

        let up = Game.isKeyPressed(keyW()) or Game.isKeyPressed(keyUp());
        let down = Game.isKeyPressed(keyS()) or Game.isKeyPressed(keyDown());
        let left = Game.isKeyPressed(keyA()) or Game.isKeyPressed(keyLeft());
        let right = Game.isKeyPressed(keyD()) or Game.isKeyPressed(keyRight());

        let isMoving = not Vec2D.isZeroApprox(Vec2D.sub(state#targetPos, state#currentPos));

        if (isMoving) {
            // Smoothly move towards target
            let newPos = Vec2D.moveToward(state#currentPos, state#targetPos, moveSpeed() * dt);
            let newScene = RogueScene.setPlayerPosition(newPos, state#scene);
            {currentPos = newPos, scene = newScene | state}
        } else {
            // Accept new input when stopped — holding a key repeats movement
            if (up) movePlayer(SceneTree.Direction.Up, state)
            else if (down) movePlayer(SceneTree.Direction.Down, state)
            else if (left) movePlayer(SceneTree.Direction.Left, state)
            else if (right) movePlayer(SceneTree.Direction.Right, state)
            else state
        }

    // ========================================================================
    // Player Movement
    // ========================================================================

    def directionToVec(dir: SceneTree.Direction): Vec2D.Vec2 =
        match dir {
            case SceneTree.Direction.Up    => {x = 0.0f32, y = -1.0f32}
            case SceneTree.Direction.Down  => {x = 0.0f32, y = 1.0f32}
            case SceneTree.Direction.Left  => {x = -1.0f32, y = 0.0f32}
            case SceneTree.Direction.Right => {x = 1.0f32, y = 0.0f32}
        }

    def canMoveToward(dir: SceneTree.Direction, state: GameState): Bool =
        let dirVec = directionToVec(dir);
        let updatedScene = SceneTree.updateRaycast("PlayerRaycast",
            rd -> {direction = dirVec | rd}, state#scene);
        run {
            SceneTree.processRaycasts(updatedScene);
            false
        } with handler SceneTree.OnRaycast {
            def rayHit(_name, hit, _k) = match hit {
                case Some(h) => not h#isSolid
                case None => false
            }
        }

    pub def movePlayer(dir: SceneTree.Direction, state: GameState): GameState =
        let dx = match dir {
            case SceneTree.Direction.Left  => -1
            case SceneTree.Direction.Right => 1
            case _                         => 0
        };
        let dy = match dir {
            case SceneTree.Direction.Up   => -1
            case SceneTree.Direction.Down => 1
            case _                        => 0
        };
        let newX = state#playerGridX + dx;
        let newY = state#playerGridY + dy;
        let newScene = RogueScene.setPlayerFacing(dir, state#scene);
        if (canMoveToward(dir, state)) {
            let newTarget = {x = Int32.toFloat32(newX) * tileSize(), y = Int32.toFloat32(newY) * tileSize()};
            {playerGridX = newX, playerGridY = newY, facing = dir,
             targetPos = newTarget, scene = newScene | state}
        } else {
            {facing = dir, scene = newScene | state}
        }
}
