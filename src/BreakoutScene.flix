// BreakoutScene — scene construction, accessor APIs, and rendering effects

mod BreakoutScene {
    pub def ballName(): String = "Ball"
    pub def paddleName(): String = "Paddle"
    pub def bricksName(): String = "Bricks"
    pub def deathZoneName(): String = "DeathZone"
    pub def rootName(): String = "Root"
    pub def powerUpsGroupName(): String = "PowerUps"

    // ========================================================================
    // Scene Building
    // ========================================================================

    pub def buildBrickSubtree(level: Game.LevelData): SceneTree.Node =
        let brickNodes = level#bricks |> List.zipWithIndex |> List.map(match (idx, brick) ->
            let idxStr = Int32.toString(idx);
            SceneTree.staticBody2D(
                "Brick_${idxStr}",
                brick#position,
                {isSolid = brick#isSolid, destroyed = false},
                SceneTree.sprite2D(
                    "BrickSprite_${idxStr}",
                    Vec2D.zero(),
                    {size = brick#size, color = brick#color, texture = brick#texture, visible = true}
                ) ::
                SceneTree.collisionShape2D(
                    "BrickCollider_${idxStr}",
                    SceneTree.CollisionShapeData.RectShape(brick#size)
                ) :: Nil
            )
        );
        SceneTree.node2D(bricksName(), Vec2D.zero(), brickNodes)

    pub def buildInitialScene(width: Int32, height: Int32, level: Game.LevelData): SceneTree.Node =
        let sw = Int32.toFloat32(width);
        let sh = Int32.toFloat32(height);
        let playerX = sw / 2.0f32 - Game.playerWidth() / 2.0f32;
        let playerY = sh - Game.playerHeight();
        let ballX = playerX + Game.playerWidth() / 2.0f32 - Game.ballRadiusConst();
        let ballY = playerY - Game.ballRadiusConst() * 2.0f32;
        let ballDiam = Game.ballRadiusConst() * 2.0f32;

        SceneTree.node2D(rootName(), Vec2D.zero(),
            SceneTree.sprite2D("Background",
                Vec2D.zero(),
                {size = {x = sw, y = sh}, color = {r = 1.0f32, g = 1.0f32, b = 1.0f32}, texture = "background", visible = true}
            ) ::
            buildBrickSubtree(level)
            ::
            SceneTree.kinematicBody2D(paddleName(),
                {x = playerX, y = playerY},
                {velocity = Vec2D.zero()},
                SceneTree.sprite2D("PaddleSprite",
                    Vec2D.zero(),
                    {size = {x = Game.playerWidth(), y = Game.playerHeight()}, color = {r = 1.0f32, g = 1.0f32, b = 1.0f32}, texture = "paddle", visible = true}
                ) ::
                SceneTree.collisionShape2D("PaddleCollider",
                    SceneTree.CollisionShapeData.RectShape({x = Game.playerWidth(), y = Game.playerHeight()})
                ) :: Nil
            )
            ::
            SceneTree.rigidBody2D(ballName(),
                {x = ballX, y = ballY},
                {velocity = {x = Game.initialBallVelocityX(), y = Game.initialBallVelocityY()}, stuck = true},
                SceneTree.sprite2D("BallSprite",
                    Vec2D.zero(),
                    {size = {x = ballDiam, y = ballDiam}, color = {r = 1.0f32, g = 1.0f32, b = 1.0f32}, texture = "ball", visible = true}
                ) ::
                SceneTree.collisionShape2D("BallCollider",
                    SceneTree.CollisionShapeData.CircleShape(Game.ballRadiusConst())
                ) :: Nil
            )
            ::
            SceneTree.area2D(deathZoneName(),
                {x = 0.0f32, y = sh},
                {velocity = Vec2D.zero()},
                SceneTree.collisionShape2D("DeathZoneShape",
                    SceneTree.CollisionShapeData.RectShape({x = sw, y = 20.0f32})
                ) :: Nil
            )
            ::
            SceneTree.node2D(powerUpsGroupName(), Vec2D.zero(), Nil)
            :: Nil
        )

    // ========================================================================
    // Snapshot Types
    // ========================================================================

    pub type alias BallSnapshot = {
        pos = Vec2D.Vec2,
        vel = Vec2D.Vec2,
        radius = Float32,
        stuck = Bool
    }

    pub type alias PaddleSnapshot = {
        pos = Vec2D.Vec2,
        size = Vec2D.Vec2
    }

    // ========================================================================
    // Snapshot APIs (one findNode per snapshot)
    // ========================================================================

    pub def ballSnapshot(scene: SceneTree.Node): BallSnapshot =
        match SceneTree.findNode(ballName(), scene) {
            case Some(n) =>
                let bd = SceneTree.rigidBodyData(n);
                {
                    pos = SceneTree.nodePosition(n),
                    vel = bd |> Option.map(b -> b#velocity) |> Option.getWithDefault(Vec2D.zero()),
                    radius = SceneTree.findCircleShape(SceneTree.nodeChildren(n)) |> Option.getWithDefault(Game.ballRadiusConst()),
                    stuck = bd |> Option.map(b -> b#stuck) |> Option.getWithDefault(true)
                }
            case None => {pos = Vec2D.zero(), vel = Vec2D.zero(), radius = Game.ballRadiusConst(), stuck = true}
        }

    pub def paddleSnapshot(scene: SceneTree.Node): PaddleSnapshot =
        match SceneTree.findNode(paddleName(), scene) {
            case Some(n) => {
                pos = SceneTree.nodePosition(n),
                size = SceneTree.findRectShape(SceneTree.nodeChildren(n))
                    |> Option.getWithDefault({x = Game.playerWidth(), y = Game.playerHeight()})
            }
            case None => {pos = Vec2D.zero(), size = {x = Game.playerWidth(), y = Game.playerHeight()}}
        }

    // ========================================================================
    // Write APIs
    // ========================================================================

    pub def setPaddleVelocity(vel: Vec2D.Vec2, scene: SceneTree.Node): SceneTree.Node =
        SceneTree.updateKinematicBody(paddleName(),
            _ -> {velocity = vel},
            scene)

    pub def updateBall(f: SceneTree.RigidBodyData -> SceneTree.RigidBodyData, scene: SceneTree.Node): SceneTree.Node =
        SceneTree.updateRigidBody(ballName(), f, scene)

    // ========================================================================
    // Physics Step
    // ========================================================================

    def physicsConfig(scene: SceneTree.Node, screenSize: Vec2D.Vec2): SceneTree.PhysicsConfig =
        let paddle = paddleSnapshot(scene);
        {
            screenSize = screenSize,
            anchorPos = paddle#pos,
            anchorWidth = paddle#size#x
        }

    /// Physics step + collision signals with pass-through support.
    pub def stepAndCollide(scene: SceneTree.Node, dt: Float32, screenSize: Vec2D.Vec2, passThrough: Bool): SceneTree.Node \ SceneTree.OnCollision =
        if (passThrough) {
            let shouldResolve = event -> match event#targetKind {
                case SceneTree.NodeKind.Fixed(bd) => bd#isSolid
                case _ => true
            };
            SceneTree.stepAndCollideFiltered(scene, dt, physicsConfig(scene, screenSize), shouldResolve)
        } else
            SceneTree.stepAndCollide(scene, dt, physicsConfig(scene, screenSize))

    pub def destroyBrick(blick: SceneTree.BodyContact, scene: SceneTree.Node): SceneTree.Node =
        SceneTree.updateStaticBody(blick#name, bd -> {destroyed = true | bd}, scene)

    // ========================================================================
    // Paddle Width (PowerUp: PadSizeIncrease)
    // ========================================================================

    pub def increasePaddleWidth(amount: Float32, scene: SceneTree.Node): SceneTree.Node =
        SceneTree.updateChildSpriteAndShape(paddleName(),
            sd -> {size = {x = sd#size#x + amount, y = sd#size#y} | sd},
            shape -> match shape {
                case SceneTree.CollisionShapeData.RectShape(sz) =>
                    SceneTree.CollisionShapeData.RectShape({x = sz#x + amount, y = sz#y})
                case other => other
            },
            scene)

    pub def resetPaddleWidth(scene: SceneTree.Node): SceneTree.Node =
        SceneTree.updateChildSpriteAndShape(paddleName(),
            sd -> {size = {x = Game.playerWidth(), y = Game.playerHeight()} | sd},
            shape -> match shape {
                case SceneTree.CollisionShapeData.RectShape(_) =>
                    SceneTree.CollisionShapeData.RectShape({x = Game.playerWidth(), y = Game.playerHeight()})
                case other => other
            },
            scene)

    // ========================================================================
    // Sprite Color (Visual effects for active powerups)
    // ========================================================================

    pub def setPaddleSpriteColor(color: Game.Vec3, scene: SceneTree.Node): SceneTree.Node =
        SceneTree.updateChildSprite(paddleName(), sd -> {color = color | sd}, scene)

    pub def setBallSpriteColor(color: Game.Vec3, scene: SceneTree.Node): SceneTree.Node =
        SceneTree.updateChildSprite(ballName(), sd -> {color = color | sd}, scene)

    // ========================================================================
    // PowerUp Scene Management
    // ========================================================================

    pub def buildPowerUpNode(name: String, powerUp: Game.PowerUpInfo): SceneTree.Node =
        SceneTree.area2D(
            name,
            powerUp#position,
            {velocity = powerUp#velocity},
            SceneTree.sprite2D(
                "${name}_Sprite",
                Vec2D.zero(),
                {size = powerUp#size, color = powerUp#color, texture = powerUp#texture, visible = true}
            ) ::
            SceneTree.collisionShape2D(
                "${name}_Collider",
                SceneTree.CollisionShapeData.RectShape(powerUp#size)
            ) :: Nil
        )

    pub def addPowerUpToField(puNode: SceneTree.Node, scene: SceneTree.Node): SceneTree.Node =
        SceneTree.mapNode(powerUpsGroupName(), parent ->
            SceneTree.appendChildren(parent, puNode :: Nil),
            scene)

    pub def removePowerUpFromField(childName: String, scene: SceneTree.Node): SceneTree.Node =
        SceneTree.removeChild(powerUpsGroupName(), childName, scene)

    pub def getFieldPowerUps(scene: SceneTree.Node): List[SceneTree.Node] =
        match SceneTree.findNode(powerUpsGroupName(), scene) {
            case Some(n) => SceneTree.nodeChildren(n)
            case None => Nil
        }

    // ========================================================================
    // Chaos: small continuous vibration using remaining time as oscillation phase
    // ========================================================================

    pub def applyChaosOffset(chaosRemaining: Float32, scene: SceneTree.Node): SceneTree.Node =
        let ampX = 8.0f32;
        let ampY = 6.0f32;
        let freqX = 50.0f32;
        let freqY = 40.0f32;
        let ox = Vec2D.sin32(chaosRemaining * freqX) * ampX;
        let oy = Vec2D.cos32(chaosRemaining * freqY) * ampY;
        SceneTree.setNodePosition(rootName(), {x = ox, y = oy}, scene)

    // ========================================================================
    // Rendering: apply shake offset
    // ========================================================================

    pub def applyShake(shakeTime: Float32, scene: SceneTree.Node): SceneTree.Node =
        let shake = shakeOffset(shakeTime);
        let currentPos = match SceneTree.findNode(rootName(), scene) {
            case Some(n) => SceneTree.nodePosition(n)
            case None => Vec2D.zero()
        };
        SceneTree.setNodePosition(rootName(), Vec2D.add(currentPos, shake), scene)

    // ========================================================================
    // Shake calculation
    // ========================================================================

    /// shakeTime (0.15 → 0 へ毎フレーム減衰) から画面オフセットを生成する。
    ///
    /// sin/cos の位相をずらして楕円状のリサージュ振動を作り、
    /// shakeTime を振幅の係数にすることで自然に減衰させる。
    ///
    ///   振幅
    ///    |*              sin(t*freqX) * t * ampX  (x軸)
    ///    | *             cos(t*freqY) * t * ampY  (y軸)
    ///    |  *
    ///    |    *  *  *
    ///    +-------------- t → 0
    ///   0.15           0.0
    ///
    /// t が大きいほど高周波・大振幅で揺れ、0 に近づくと静止する。
    pub def shakeOffset(shakeTime: Float32): Vec2D.Vec2 =
        if (shakeTime <= 0.0f32) Vec2D.zero()
        else {
            let freqX = 100.0f32;
            let freqY = 80.0f32;
            let ampX  = 80.0f32;
            let ampY  = 60.0f32;
            let ox = Vec2D.sin32(shakeTime * freqX) * shakeTime * ampX;
            let oy = Vec2D.cos32(shakeTime * freqY) * shakeTime * ampY;
            {x = ox, y = oy}
        }
}
