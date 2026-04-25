// Game module — types, effects, constants, level parsing, and game logic

mod Game {
    pub type alias Vec3 = {r = Float32, g = Float32, b = Float32}

    pub type alias BrickTemplate = {
        position = Vec2D.Vec2,
        size = Vec2D.Vec2,
        color = Vec3,
        isSolid = Bool,
        texture = String
    }

    pub type alias LevelData = {
        bricks = List[BrickTemplate]
    }

    // ========================================================================
    // PowerUp Types
    // ========================================================================

    pub enum PowerUpType with Eq, ToString {
        case Speed
        case Sticky
        case PassThrough
        case PadSizeIncrease
        case Confuse
        case Chaos
    }

    pub type alias PowerUpInfo = {
        powerUpType = PowerUpType,
        position = Vec2D.Vec2,
        size = Vec2D.Vec2,
        velocity = Vec2D.Vec2,
        color = Vec3,
        texture = String,
        duration = Float32
    }

    pub type alias ActiveEffect = {
        powerUpType = PowerUpType,
        remainingTime = Float32
    }

    pub type alias FieldPowerUp = {
        powerUpType = PowerUpType,
        duration = Float32
    }

    pub type alias GameState = {
        scene = SceneTree.Node,
        levels = List[LevelData],
        currentLevel = Int32,
        shakeTime = Float32,
        powerUpsInField = Map[String, FieldPowerUp],
        powerUpCounter = Int32,
        activeEffects = List[ActiveEffect]
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
    pub def playerWidth(): Float32 = 100.0f32
    pub def playerHeight(): Float32 = 20.0f32
    pub def playerVelocity(): Float32 = 500.0f32
    pub def ballRadiusConst(): Float32 = 12.5f32
    pub def initialBallVelocityX(): Float32 = 100.0f32
    pub def initialBallVelocityY(): Float32 = -350.0f32

    pub def keyA(): Int32 = 65
    pub def keyD(): Int32 = 68
    pub def keySpace(): Int32 = 32

    pub def powerUpSizeX(): Float32 = 60.0f32
    pub def powerUpSizeY(): Float32 = 20.0f32
    pub def powerUpVelocityY(): Float32 = 150.0f32

    // ========================================================================
    // Texture Manifest
    // ========================================================================

    pub def textureManifest(): List[(String, String, Bool)] =
        ("background", "textures/background.jpg", false) ::
        ("block",      "textures/block.png",      true) ::
        ("block_solid", "textures/block_solid.png", true) ::
        ("paddle",     "textures/paddle.png",      true) ::
        ("ball",       "textures/awesomeface.png", true) ::
        ("powerup_speed",       "textures/powerup_speed.png",       true) ::
        ("powerup_sticky",      "textures/powerup_sticky.png",      true) ::
        ("powerup_passthrough", "textures/powerup_passthrough.png", true) ::
        ("powerup_increase",    "textures/powerup_increase.png",    true) ::
        ("powerup_confuse",     "textures/powerup_confuse.png",     true) ::
        ("powerup_chaos",       "textures/powerup_chaos.png",       true) ::
        Nil

    // ========================================================================
    // PowerUp Helpers
    // ========================================================================

    pub def powerUpColor(powerUpType: PowerUpType): Vec3 =
        match powerUpType {
            case PowerUpType.Speed          => {r = 0.5f32, g = 0.5f32, b = 1.0f32}
            case PowerUpType.Sticky         => {r = 1.0f32, g = 0.5f32, b = 1.0f32}
            case PowerUpType.PassThrough    => {r = 0.5f32, g = 1.0f32, b = 0.5f32}
            case PowerUpType.PadSizeIncrease => {r = 1.0f32, g = 0.6f32, b = 0.4f32}
            case PowerUpType.Confuse        => {r = 1.0f32, g = 0.3f32, b = 0.3f32}
            case PowerUpType.Chaos          => {r = 0.9f32, g = 0.25f32, b = 0.25f32}
        }

    pub def powerUpTexture(powerUpType: PowerUpType): String =
        match powerUpType {
            case PowerUpType.Speed          => "powerup_speed"
            case PowerUpType.Sticky         => "powerup_sticky"
            case PowerUpType.PassThrough    => "powerup_passthrough"
            case PowerUpType.PadSizeIncrease => "powerup_increase"
            case PowerUpType.Confuse        => "powerup_confuse"
            case PowerUpType.Chaos          => "powerup_chaos"
        }

    pub def powerUpDuration(powerUpType: PowerUpType): Float32 =
        match powerUpType {
            case PowerUpType.Speed          => 0.0f32
            case PowerUpType.Sticky         => 20.0f32
            case PowerUpType.PassThrough    => 10.0f32
            case PowerUpType.PadSizeIncrease => 0.0f32
            case PowerUpType.Confuse        => 15.0f32
            case PowerUpType.Chaos          => 8.0f32
        }

    pub def makePowerUp(powerUpType: PowerUpType, position: Vec2D.Vec2): PowerUpInfo =
        {
            powerUpType = powerUpType,
            position = position,
            size = {x = powerUpSizeX(), y = powerUpSizeY()},
            velocity = {x = 0.0f32, y = powerUpVelocityY()},
            color = powerUpColor(powerUpType),
            texture = powerUpTexture(powerUpType),
            duration = powerUpDuration(powerUpType)
        }

    /// Roll random chance to spawn a powerup at the given position.
    /// Positive powerups: 1 in 75 each (4 types).
    /// Negative powerups: 1 in 15 each (2 types).
    pub def trySpawnPowerUp(position: Vec2D.Vec2): Option[PowerUpInfo] \ Math.Random =
        let r1 = Math.Random.randomFloat64();
        let r2 = Math.Random.randomFloat64();
        let r3 = Math.Random.randomFloat64();
        let r4 = Math.Random.randomFloat64();
        let r5 = Math.Random.randomFloat64();
        let r6 = Math.Random.randomFloat64();
        let t75 = 1.0 / 75.0;
        let t15 = 1.0 / 15.0;
        if (r1 < t75)
            Some(makePowerUp(PowerUpType.Speed, position))
        else if (r2 < t75)
            Some(makePowerUp(PowerUpType.Sticky, position))
        else if (r3 < t75)
            Some(makePowerUp(PowerUpType.PassThrough, position))
        else if (r4 < t75)
            Some(makePowerUp(PowerUpType.PadSizeIncrease, position))
        else if (r5 < t15)
            Some(makePowerUp(PowerUpType.Confuse, position))
        else if (r6 < t15)
            Some(makePowerUp(PowerUpType.Chaos, position))
        else
            None

    /// Check if a powerup of the given type is currently active.
    pub def isEffectActive(powerUpType: PowerUpType, effects: List[ActiveEffect]): Bool =
        List.exists(effect -> effect#powerUpType == powerUpType, effects)

    // ========================================================================
    // Level Parsing
    // ========================================================================

    def loadLevel(path: String, levelWidth: Int32, levelHeight: Int32): LevelData \ Fs.FileRead =
        match Fs.FileRead.read(path) {
            case Ok(data) => parseLevel(data, levelWidth, levelHeight)
            case Err(_) => bug!("Failed to load level: ${path}")
        }

    pub def parseLevel(data: String, levelWidth: Int32, levelHeight: Int32): LevelData =
        let validRows = data
            |> String.split({regex = "\n"})
            |> List.map(parseLevelLine)
            |> List.filter(row -> not List.isEmpty(row));
        let numRows = List.length(validRows);
        let numCols = List.head(validRows) |> Option.map(List.length) |> Option.getWithDefault(0);

        let unitWidth = if (numCols > 0) Int32.toFloat32(levelWidth) / Int32.toFloat32(numCols) else 0.0f32;
        let unitHeight = if (numRows > 0) Int32.toFloat32(levelHeight) / Int32.toFloat32(numRows) else 0.0f32;

        let bricks = buildBricks(validRows, unitWidth, unitHeight);
        {bricks = bricks}

    pub def parseLevelLine(line: String): List[Int32] =
        let trimmed = String.trim(line);
        if (String.isEmpty(trimmed)) Nil
        else
            trimmed
                |> String.split({regex = " "})
                |> List.filterMap(s -> {
                    let t = String.trim(s);
                    if (String.isEmpty(t)) None else Int32.fromString(t)
                })

    def buildBricks(rows: List[List[Int32]], unitW: Float32, unitH: Float32): List[BrickTemplate] =
        rows |> (List.zipWithIndex >> List.flatMap(match (rowIdx, row) ->
            buildBrickRow(row, rowIdx, unitW, unitH)
        ))

    def buildBrickRow(row: List[Int32], rowIdx: Int32, unitW: Float32, unitH: Float32): List[BrickTemplate] =
        row |> (List.zipWithIndex >> List.filterMap(match (colIdx, tileType) ->
            if (tileType == 0) None
            else Some({
                position = {x = Int32.toFloat32(colIdx) * unitW, y = Int32.toFloat32(rowIdx) * unitH},
                size = {x = unitW, y = unitH},
                color = tileColor(tileType),
                isSolid = (tileType == 1),
                texture = if (tileType == 1) "block_solid" else "block"
            })
        ))

    def tileColor(tileType: Int32): Vec3 =
        match tileType {
            case 1 => {r = 0.8f32, g = 0.8f32, b = 0.7f32}
            case 2 => {r = 0.2f32, g = 0.6f32, b = 1.0f32}
            case 3 => {r = 0.0f32, g = 0.7f32, b = 0.0f32}
            case 4 => {r = 0.8f32, g = 0.8f32, b = 0.4f32}
            case 5 => {r = 1.0f32, g = 0.5f32, b = 0.0f32}
            case _ => {r = 1.0f32, g = 1.0f32, b = 1.0f32}
        }

    // ========================================================================
    // Game Initialization
    // ========================================================================

    pub def initGame(width: Int32, height: Int32): GameState \ Fs.FileRead =
        let level1 = loadLevel("levels/one.lvl", width, height / 2);
        let level2 = loadLevel("levels/two.lvl", width, height / 2);
        let level3 = loadLevel("levels/three.lvl", width, height / 2);
        let level4 = loadLevel("levels/four.lvl", width, height / 2);
        let levels = level1 :: level2 :: level3 :: level4 :: Nil;
        let scene = BreakoutScene.buildInitialScene(width, height, level1);
        {
            scene = scene,
            levels = levels,
            currentLevel = 0,
            shakeTime = 0.0f32,
            powerUpsInField = Map.empty(),
            powerUpCounter = 0,
            activeEffects = Nil
        }

    // ========================================================================
    // Game Loop
    // ========================================================================

    pub def startGame(): GameState \ Game + Math.Random =
        let state = Game.getInitialState();
        runLoop(state)

    @Tailrec
    def runLoop(state: GameState): GameState \ Game + Math.Random =
        if (Game.shouldClose()) state
        else {
            let newState = updateGame(state);
            let sceneWithEffects = applyVisualEffects(newState);
            let renderScene = BreakoutScene.applyShake(newState#shakeTime, sceneWithEffects);
            Game.render(renderScene);
            runLoop(newState)
        }

    // ========================================================================
    // Game Logic — per-frame update
    // ========================================================================

    def updateGame(state: GameState): GameState \ Game + Math.Random =
        let dt = Game.getDeltaTime();
        let screenSize = {x = Int32.toFloat32(screenWidth()), y = Int32.toFloat32(screenHeight())};
        state
            |> processInput
            |> applyCollisions(dt, screenSize)
            |> updateActiveEffects(dt)
            |> tickShake(dt)

    // ========================================================================
    // Input Processing
    // ========================================================================

    pub def processInput(state: GameState): GameState \ Game =
        let confuseActive = isEffectActive(PowerUpType.Confuse, state#activeEffects);
        let velLeft = if (Game.isKeyPressed(keyA())) -1.0f32 * playerVelocity() else 0.0f32;
        let velRight = if (Game.isKeyPressed(keyD())) playerVelocity() else 0.0f32;
        let rawVelX = velLeft + velRight;
        let paddleVelX = if (confuseActive) -1.0f32 * rawVelX else rawVelX;
        let withPaddle = {scene = BreakoutScene.setPaddleVelocity({x = paddleVelX, y = 0.0f32}, state#scene) | state};
        if (Game.isKeyPressed(keySpace()))
            {scene = BreakoutScene.updateBall(bd -> {stuck = false | bd}, withPaddle#scene) | withPaddle}
        else withPaddle


    pub def applyCollisions(dt: Float32, screenSize: Vec2D.Vec2, state: GameState): GameState \ Math.Random =
        let passThrough = isEffectActive(PowerUpType.PassThrough, state#activeEffects);
        run {
            let newScene = BreakoutScene.stepAndCollide(state#scene, dt, screenSize, passThrough);
            {scene = newScene | state}
        } with handler SceneTree.OnCollision {
            def bodyEntered(nodeName, selfPos, body, k) =
                let s = k(());
                if (nodeName == BreakoutScene.ballName())
                    onBallBodyEntered(selfPos, body, s)
                else s
            def areaEntered(nodeName, _selfPos, body, k) =
                let s = k(());
                if (nodeName == BreakoutScene.ballName())
                    onBallAreaEntered(body, s)
                else if (nodeName == BreakoutScene.paddleName() and body#group == BreakoutScene.powerUpsGroupName())
                    onPaddleAreaEntered(body, s)
                else if (body#name == BreakoutScene.deathZoneName())
                    onPowerUpDeathZone(nodeName, s)
                else s
        }
    // ========================================================================
    // Collision Handlers (Godot _on_*_entered style)
    // ========================================================================

    def onBallBodyEntered(selfPos: Vec2D.Vec2, body: SceneTree.BodyContact,
                          state: GameState): GameState \ Math.Random =
        if(body#name == BreakoutScene.paddleName()) {
            let stickyActive = isEffectActive(PowerUpType.Sticky, state#activeEffects);
            let direction = Vec2D.normalized(Vec2D.sub(selfPos, body#position));
            let speed = BreakoutScene.ballSnapshot(state#scene)#vel |> Vec2D.length;
            let newVelocity = Vec2D.mul(direction, speed);
            let newScene = if (stickyActive)
                BreakoutScene.updateBall(_ -> {velocity = newVelocity, stuck = true}, state#scene)
            else
                BreakoutScene.updateBall(bd -> {velocity = newVelocity | bd}, state#scene);
            {scene = newScene | state}
        } else if(body#group == BreakoutScene.bricksName()) {
            if (body#isSolid)
                {shakeTime = 0.15f32 | state}
            else {
                let destroyedScene = BreakoutScene.destroyBrick(body, state#scene);
                match trySpawnPowerUp(body#position) {
                    case Some(powerUp) =>
                        let powerUpName = "PowerUp_${Int32.toString(state#powerUpCounter)}";
                        let powerUpNode = BreakoutScene.buildPowerUpNode(powerUpName, powerUp);
                        let meta: FieldPowerUp = {powerUpType = powerUp#powerUpType, duration = powerUp#duration};
                        let newScene = BreakoutScene.addPowerUpToField(powerUpNode, destroyedScene);
                        {scene = newScene,
                         powerUpsInField = Map.insert(powerUpName, meta, state#powerUpsInField),
                         powerUpCounter = state#powerUpCounter + 1 | state}
                    case None =>
                        {scene = destroyedScene | state}
                }
            }
         } else state

    def onBallAreaEntered(body: SceneTree.BodyContact,
                          state: GameState): GameState =
        if(body#name == BreakoutScene.deathZoneName())
            let resetScene = BreakoutScene.updateBall(
                _ -> {velocity = {x = initialBallVelocityX(), y = initialBallVelocityY()},
                        stuck = true}, state#scene);
            let clearedScene = BreakoutScene.getFieldPowerUps(resetScene)
                |> List.foldLeft((scene, node) ->
                    BreakoutScene.removePowerUpFromField(SceneTree.nodeName(node), scene),
                    resetScene);
            {scene = clearedScene, powerUpsInField = Map.empty(), activeEffects = Nil | state}
                |> resetAllEffects
        else state

    def onPaddleAreaEntered(body: SceneTree.BodyContact, state: GameState): GameState =
        let powerUpName = body#name;
        match Map.get(powerUpName, state#powerUpsInField) {
            case Some(meta) =>
                let activated = activatePowerUp(meta, state);
                {scene = BreakoutScene.removePowerUpFromField(powerUpName, activated#scene),
                 powerUpsInField = Map.remove(powerUpName, activated#powerUpsInField) | activated}
            case None => state
        }

    def onPowerUpDeathZone(powerUpName: String, state: GameState): GameState =
        {scene = BreakoutScene.removePowerUpFromField(powerUpName, state#scene),
         powerUpsInField = Map.remove(powerUpName, state#powerUpsInField) | state}

    pub def tickShake(dt: Float32, state: GameState): GameState =
        if (state#shakeTime > 0.0f32)
            {shakeTime = Float32.max(0.0f32, state#shakeTime - dt) | state}
        else state

    // ========================================================================
    // PowerUp Activation
    // ========================================================================

    pub def activatePowerUp(meta: FieldPowerUp, state: GameState): GameState =
        let effect: ActiveEffect = {powerUpType = meta#powerUpType, remainingTime = meta#duration};
        let withEffect = if (meta#duration > 0.0f32)
            {activeEffects = effect :: state#activeEffects | state}
        else state;
        match meta#powerUpType {
            case PowerUpType.Speed =>
                let newVelocity = Vec2D.mul(BreakoutScene.ballSnapshot(withEffect#scene)#vel, 1.2f32);
                {scene = BreakoutScene.updateBall(bd -> {velocity = newVelocity | bd}, withEffect#scene) | withEffect}
            case PowerUpType.PadSizeIncrease =>
                {scene = BreakoutScene.increasePaddleWidth(50.0f32, withEffect#scene) | withEffect}
            case _ => withEffect
        }

    // ========================================================================
    // Active Effect Tick & Deactivation
    // ========================================================================

    pub def updateActiveEffects(dt: Float32, state: GameState): GameState =
        let (remaining, expired) = List.foldRight((effect, acc) ->
            let newTime = effect#remainingTime - dt;
            if (newTime <= 0.0f32)
                (fst(acc), effect :: snd(acc))
            else
                ({remainingTime = newTime | effect} :: fst(acc), snd(acc))
        , (Nil, Nil), state#activeEffects);
        let withRemaining = {activeEffects = remaining | state};
        List.foldLeft((acc, effect) -> deactivatePowerUp(effect#powerUpType, acc), withRemaining, expired)

    def deactivatePowerUp(powerUpType: PowerUpType, state: GameState): GameState =
        if (isEffectActive(powerUpType, state#activeEffects))
            state
        else match powerUpType {
            case PowerUpType.Sticky =>
                state
            case PowerUpType.PassThrough =>
                state
            case PowerUpType.Confuse =>
                state
            case PowerUpType.Chaos =>
                state
            case _ => state
        }

    /// Reset all effects back to default state (called on death).
    def resetAllEffects(state: GameState): GameState =
        {scene = BreakoutScene.resetPaddleWidth(state#scene) | state}

    // ========================================================================
    // Visual Effects (applied per-frame for rendering only)
    // ========================================================================

    def applyVisualEffects(state: GameState): SceneTree.Node =
        let stickyActive = isEffectActive(PowerUpType.Sticky, state#activeEffects);
        let passThroughActive = isEffectActive(PowerUpType.PassThrough, state#activeEffects);
        let confuseActive = isEffectActive(PowerUpType.Confuse, state#activeEffects);
        // Paddle color: sticky=magenta, confuse=red, default=white
        let paddleColor = if (stickyActive) {r = 1.0f32, g = 0.5f32, b = 1.0f32}
            else if (confuseActive) {r = 1.0f32, g = 0.3f32, b = 0.3f32}
            else {r = 1.0f32, g = 1.0f32, b = 1.0f32};
        // Ball color: passthrough=red/pink, default=white
        let ballColor = if (passThroughActive) {r = 1.0f32, g = 0.5f32, b = 0.5f32}
            else {r = 1.0f32, g = 1.0f32, b = 1.0f32};
        // Chaos: continuous screen vibration
        let chaosRemaining = List.findMap(effect ->
            if (effect#powerUpType == PowerUpType.Chaos) Some(effect#remainingTime) else None,
            state#activeEffects) |> Option.getWithDefault(0.0f32);
        let scene = state#scene
            |> BreakoutScene.setPaddleSpriteColor(paddleColor)
            |> BreakoutScene.setBallSpriteColor(ballColor);
        if (chaosRemaining > 0.0f32)
            BreakoutScene.applyChaosOffset(chaosRemaining, scene)
        else scene
}
