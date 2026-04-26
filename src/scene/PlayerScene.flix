// PlayerScene — player construction, UV, APIs, and movement

mod PlayerScene {
    pub def playerName(): String = "Player"

    // ========================================================================
    // Sprite Sheet Layout (npc.png: 240x128 = 15 columns x 8 rows, 16x16 each)
    // ========================================================================
    //
    // Each character: 3 columns (animation frames) x 4 rows (directions).
    // Characters tiled: 4 across x 2 down.
    // Using the first character (cols 0-2, rows 0-3):
    //   Row 0: facing down  (front view)
    //   Row 1: facing left
    //   Row 2: facing right
    //   Row 3: facing up    (back view)
    //
    // Idle frame = col 0 of each direction row.

    /// Returns (uvOffset, uvScale) for the idle frame of the given direction.
    ///
    /// STBImage flips the image vertically on load, so in UV space:
    ///   UV y=1.0 -> top of original image (row 0)
    ///   UV y=0.0 -> bottom of original image (row 7)
    ///
    /// We use negative uvScale.y so that screen-top -> character-head (right-side up).
    pub def uvForDirection(dir: SceneTree.Direction): (Vec2D.Vec2, Vec2D.Vec2) =
        let frameW = 1.0f32 / 15.0f32;
        let frameH = 1.0f32 / 8.0f32;
        let uvScaleY = -1.0f32 * frameH;
        match dir {
            case SceneTree.Direction.Down  =>
                ({x = 0.0f32, y = 1.0f32},            {x = frameW, y = uvScaleY})
            case SceneTree.Direction.Left  =>
                ({x = 0.0f32, y = 7.0f32 * frameH},   {x = frameW, y = uvScaleY})
            case SceneTree.Direction.Right =>
                ({x = 0.0f32, y = 6.0f32 * frameH},   {x = frameW, y = uvScaleY})
            case SceneTree.Direction.Up    =>
                ({x = 0.0f32, y = 5.0f32 * frameH},   {x = frameW, y = uvScaleY})
        }

    // ========================================================================
    // Player Node Building
    // ========================================================================

    pub def buildPlayer(playerGridX: Int32, playerGridY: Int32, tileSz: Float32, moveSpd: Float32): SceneTree.Node =
        let px = Int32.toFloat32(playerGridX) * tileSz;
        let py = Int32.toFloat32(playerGridY) * tileSz;
        let (uvOff, uvSc) = uvForDirection(SceneTree.Direction.Down);
        let frameW = 1.0f32 / 15.0f32;
        let half = tileSz / 2.0f32;
        let playerSprite = AnimatedSprite2D.init({
                name = "PlayerSprite", pos = Vec2D.zero(),
                size = {x = tileSz, y = tileSz}, texture = "npc",
                frameCount = 3, frameWidth = frameW
            })
            |> AnimatedSprite2D.uv(uvOff, uvSc)
            |> AnimatedSprite2D.fps(4.0f32);
        let playerRaycast = Raycast2D.init({
                name = "PlayerRaycast", pos = {x = half, y = half},
                direction = {x = 0.0f32, y = 1.0f32}
            })
            |> Raycast2D.maxDistance(tileSz);
        let playerCamera = Camera2D.init({name = "PlayerCamera", pos = Vec2D.zero()})
            |> Camera2D.makeCurrent(true)
            |> Camera2D.smoothingEnabled(true)
            |> Camera2D.smoothingSpeed(5.0f32);
        CharacterBody2D.init({
                name = playerName(), pos = {x = px, y = py},
                children = playerSprite :: playerRaycast :: playerCamera :: Nil
            })
            |> CharacterBody2D.moveSpeed(moveSpd)

    // ========================================================================
    // Player APIs
    // ========================================================================

    pub def setPlayerPosition(pos: Vec2D.Vec2, scene: SceneTree.Node): SceneTree.Node =
        SceneTree.setNodePosition(playerName(), pos, scene)

    pub def getPlayerPosition(scene: SceneTree.Node): Vec2D.Vec2 =
        SceneTree.globalPosition(playerName(), scene)
            |> Option.getWithDefault(Vec2D.zero())

    pub def getPlayerTargetPos(scene: SceneTree.Node): Vec2D.Vec2 =
        SceneTree.findNode(playerName(), scene)
            |> Option.flatMap(SceneTree.characterBodyData)
            |> Option.map(cbd -> cbd#targetPos)
            |> Option.getWithDefault(Vec2D.zero())

    pub def setPlayerTarget(target: Vec2D.Vec2, scene: SceneTree.Node): SceneTree.Node =
        SceneTree.updateCharacterBody(playerName(), cbd ->
            {targetPos = target | cbd}, scene)

    pub def getPlayerTargetGrid(scene: SceneTree.Node, tileSz: Float32): Grid.GridPos =
        Grid.fromWorld(getPlayerTargetPos(scene), tileSz)

    pub def setPlayerTargetGrid(gridPos: Grid.GridPos, tileSz: Float32, scene: SceneTree.Node): SceneTree.Node =
        setPlayerTarget(Grid.toWorld(gridPos, tileSz), scene)

    pub def isPlayerMoving(scene: SceneTree.Node): Bool =
        not Vec2D.isZeroApprox(Vec2D.sub(getPlayerTargetPos(scene), getPlayerPosition(scene)))

    pub def setPlayerFacing(dir: SceneTree.Direction, scene: SceneTree.Node): SceneTree.Node =
        let (uvOff, uvSc) = uvForDirection(dir);
        SceneTree.updateChildAnimatedSprite(playerName(), asd ->
            {uvOffset = uvOff, uvScale = uvSc | asd},
            scene)

    // ========================================================================
    // Player Movement
    // ========================================================================

    def canMoveToward(dir: SceneTree.Direction, scene: SceneTree.Node): Bool \ SceneTree.OnRaycast =
        let dirVec = SceneTree.directionToVec(dir);
        let updatedScene = SceneTree.updateRaycast("PlayerRaycast",
            rd -> {direction = dirVec | rd}, scene);
        SceneTree.processRaycasts(updatedScene);
        false

    pub def movePlayer(dir: SceneTree.Direction, tileSz: Float32, scene: SceneTree.Node): SceneTree.Node =
        let canMove = run {
            canMoveToward(dir, scene)
        } with handler SceneTree.OnRaycast {
            def rayHit(_name, hit, _k) = match hit {
                case Some(h) => not h#isSolid
                case None => false
            }
        };

        if (canMove) {
            let dirVec = SceneTree.directionToVec(dir);
            let targetPos = getPlayerTargetPos(scene);
            let newTarget = Vec2D.add(targetPos, Vec2D.mul(dirVec, tileSz));
            scene
                |> setPlayerFacing(dir)
                |> setPlayerTarget(newTarget)
        } else {
            scene |> setPlayerFacing(dir)
        }
}
