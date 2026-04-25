// Tests for Breakout game logic — scene-tree based

use SceneTree.Direction.{Up, Right, Down, Left}
use Game.{parseLevelLine, parseLevel, initGame,
          playerWidth, playerHeight, ballRadiusConst,
          screenWidth, screenHeight,
          initialBallVelocityX, initialBallVelocityY,
          processInput, applyCollisions,
          keyA, keyD, keySpace,
          tickShake}

// --- parseLevelLine ---

@Test
def testParseLevelLineNormal(): Unit \ Assert =
    Assert.assertEq(expected = 1 :: 0 :: 3 :: Nil, parseLevelLine("1 0 3"))

@Test
def testParseLevelLineEmpty(): Unit \ Assert =
    Assert.assertEq(expected = (Nil: List[Int32]), parseLevelLine(""))

@Test
def testParseLevelLineTrimmed(): Unit \ Assert =
    Assert.assertEq(expected = 2 :: 5 :: Nil, parseLevelLine("  2 5  "))

// --- parseLevel ---

@Test
def testParseLevelBrickCount(): Unit \ Assert =
    let data = "5 5 5 5 5 5 5 5 5 5 5 5 5 5 5\n5 5 5 5 5 5 5 5 5 5 5 5 5 5 5\n4 4 4 4 4 0 0 0 0 0 4 4 4 4 4\n4 1 4 1 4 0 0 1 0 0 4 1 4 1 4\n3 3 3 3 3 0 0 0 0 0 3 3 3 3 3\n3 3 1 3 3 3 3 3 3 3 3 3 1 3 3\n2 2 2 2 2 2 2 2 2 2 2 2 2 2 2\n2 2 2 2 2 2 2 2 2 2 2 2 2 2 2";
    let level = parseLevel(data, 800, 300);
    Assert.assertEq(expected = 106, List.length(level#bricks))

@Test
def testParseLevelSkipsZero(): Unit \ Assert =
    let level = parseLevel("1 0 2", 300, 100);
    Assert.assertEq(expected = 2, List.length(level#bricks))

@Test
def testParseLevelBrickPosition(): Unit \ Assert =
    let level = parseLevel("0 0 3", 300, 100);
    let px = List.head(level#bricks) |> Option.map(b -> b#position#x);
    let py = List.head(level#bricks) |> Option.map(b -> b#position#y);
    Assert.assertEq(expected = Some(200.0f32), px);
    Assert.assertEq(expected = Some(0.0f32), py)

@Test
def testParseLevelSolidBrick(): Unit \ Assert =
    let level = parseLevel("1", 100, 100);
    let solid = List.head(level#bricks) |> Option.map(b -> b#isSolid);
    let tex = List.head(level#bricks) |> Option.map(b -> b#texture);
    Assert.assertEq(expected = Some(true), solid);
    Assert.assertEq(expected = Some("block_solid"), tex)

@Test
def testParseLevelNonSolidBrick(): Unit \ Assert =
    let level = parseLevel("2", 100, 100);
    let solid = List.head(level#bricks) |> Option.map(b -> b#isSolid);
    let tex = List.head(level#bricks) |> Option.map(b -> b#texture);
    let red = List.head(level#bricks) |> Option.map(b -> b#color#r);
    Assert.assertEq(expected = Some(false), solid);
    Assert.assertEq(expected = Some("block"), tex);
    Assert.assertEq(expected = Some(0.2f32), red)

// --- initGame ---

def dummyFileRead(f: Unit -> a \ ef): a \ ef - Fs.FileRead =
    run { f() } with handler Fs.FileRead {
        def read(_path, resume) = resume(Ok("1"))
        def readBytes(_path, resume) = resume(Ok(Vector#{}))
        def readLines(_path, resume) = resume(Ok("1" :: Nil))
    }

@Test
def testInitGamePaddlePosition(): Unit \ Assert =
    let state = run { initGame(800, 600) } with dummyFileRead;
    let pos = (BreakoutScene.paddleSnapshot(state#scene))#pos;
    Assert.assertEq(expected = 350.0f32, pos#x);
    Assert.assertEq(expected = 580.0f32, pos#y)

@Test
def testInitGameBallPosition(): Unit \ Assert =
    let state = run { initGame(800, 600) } with dummyFileRead;
    let pos = (BreakoutScene.ballSnapshot(state#scene))#pos;
    Assert.assertEq(expected = 387.5f32, pos#x);
    Assert.assertEq(expected = 555.0f32, pos#y)

@Test
def testInitGameBallVelocity(): Unit \ Assert =
    let state = run { initGame(800, 600) } with dummyFileRead;
    let vel = (BreakoutScene.ballSnapshot(state#scene))#vel;
    Assert.assertEq(expected = 100.0f32, vel#x);
    Assert.assertEq(expected = -350.0f32, vel#y)

@Test
def testInitGameBallStuck(): Unit \ Assert =
    let state = run { initGame(800, 600) } with dummyFileRead;
    Assert.assertTrue((BreakoutScene.ballSnapshot(state#scene))#stuck)

// --- Scene tree based test state helper ---

def mkTestState(
    px: Float32, py: Float32,
    bx: Float32, by: Float32,
    vx: Float32, vy: Float32,
    stuck: Bool
): Game.GameState =
    mkTestStateWithShake(px, py, bx, by, vx, vy, stuck, 0.0f32)

def mkTestStateWithShake(
    px: Float32, py: Float32,
    bx: Float32, by: Float32,
    vx: Float32, vy: Float32,
    stuck: Bool,
    shake: Float32
): Game.GameState =
    let scene = BreakoutScene.buildInitialScene(screenWidth(), screenHeight(), {bricks = Nil})
        |> SceneTree.setNodePosition("Paddle", {x = px, y = py})
        |> SceneTree.setNodePosition("Ball", {x = bx, y = by})
        |> BreakoutScene.updateBall(_ -> {velocity = {x = vx, y = vy}, stuck = stuck});
    {scene = scene, levels = Nil, currentLevel = 0, shakeTime = shake,
     powerUpsInField = Map.empty(), powerUpCounter = 0, activeEffects = Nil}

// --- physicsStep via engine (replaces moveBall tests) ---

def testScreenSize(): Vec2D.Vec2 = {x = 800.0f32, y = 600.0f32}

// 当たり判定は無視して、ボールの移動と壁の跳ね返りだけを確かめる。
def testAdvancePhysics(scene: SceneTree.Node, dt: Float32, paddlePos: Vec2D.Vec2): SceneTree.Node =
    let config: SceneTree.PhysicsConfig = {screenSize = testScreenSize(), anchorPos = paddlePos, anchorWidth = playerWidth()};
    run {
        SceneTree.stepAndCollide(scene, dt, config)
    } with handler SceneTree.OnCollision {
        def bodyEntered(_, _, _, k) = k(())
        def areaEntered(_, _, _, k) = k(())
    }

// くっついているボール(stuck=true)は、パドルの真上にぴったり張りつく。
//   ballX = paddleX + paddleW/2 - r = 10 + 50 - 12.5 = 47.5
//   ballY = paddleY - 直径          = 50 - 25         = 25
//
//       10          47.5  60         110
//  y=25 ............+--O--+............
//       ............|ボール|............
//  y=50 +----------[=====]----------+
//       |         パドル            |
//  y=70 +---------------------------+
//
@Test
def testPhysicsStepBallStuck(): Unit \ Assert =
    let state = mkTestState(10.0f32, 50.0f32, 30.0f32, 20.0f32, 10.0f32, -35.0f32, true);
    let newRoot = testAdvancePhysics(state#scene, 0.016f32, {x = 10.0f32, y = 50.0f32});
    let result = {scene = newRoot | state};
    let pos = (BreakoutScene.ballSnapshot(result#scene))#pos;
    let expectedX = 10.0f32 + playerWidth() / 2.0f32 - ballRadiusConst();
    let expectedY = 50.0f32 - ballRadiusConst() * 2.0f32;
    Assert.assertEq(expected = expectedX, pos#x);
    Assert.assertEq(expected = expectedY, pos#y)

// (40,20) + vel(10,-35) * dt=1.0 = (50,-5)
// 上の壁にぶつかるので y=0 で止まる
@Test
def testPhysicsStepBallNormal(): Unit \ Assert =
    let state = mkTestState(10.0f32, 200.0f32, 40.0f32, 20.0f32, 10.0f32, -35.0f32, false);
    let newRoot = testAdvancePhysics(state#scene, 1.0f32, {x = 10.0f32, y = 200.0f32});
    let result = {scene = newRoot | state};
    let pos = (BreakoutScene.ballSnapshot(result#scene))#pos;
    Assert.assertEq(expected = 50.0f32, pos#x);
    Assert.assertEq(expected = 0.0f32, pos#y)

// (5,50) + vel(-10,0) * 1.0 = (-5,50) -> 左の壁で x=0 に止まり、vx が逆向きになる
// パドルは x=200 に置いて、壁際でうっかり当たらないようにする
@Test
def testPhysicsStepBallLeftWall(): Unit \ Assert =
    let state = mkTestState(200.0f32, 50.0f32, 5.0f32, 50.0f32, -10.0f32, 0.0f32, false);
    let newRoot = testAdvancePhysics(state#scene, 1.0f32, {x = 200.0f32, y = 50.0f32});
    let result = {scene = newRoot | state};
    let pos = (BreakoutScene.ballSnapshot(result#scene))#pos;
    let vel = (BreakoutScene.ballSnapshot(result#scene))#vel;
    Assert.assertEq(expected = 0.0f32, pos#x);
    Assert.assertTrue(vel#x > 0.0f32)

// startX=765, (765,50) + vel(200,0)*1.0 = (965,50) -> 右の壁で x=775 に止まり、vx が逆向きになる
@Test
def testPhysicsStepBallRightWall(): Unit \ Assert =
    let ballSize = ballRadiusConst() * 2.0f32;
    let startX = Int32.toFloat32(screenWidth()) - ballSize - 10.0f32;
    let state = mkTestState(10.0f32, 50.0f32, startX, 50.0f32, 200.0f32, 0.0f32, false);
    let newRoot = testAdvancePhysics(state#scene, 1.0f32, {x = 10.0f32, y = 50.0f32});
    let result = {scene = newRoot | state};
    let pos = (BreakoutScene.ballSnapshot(result#scene))#pos;
    let vel = (BreakoutScene.ballSnapshot(result#scene))#vel;
    Assert.assertEq(expected = Int32.toFloat32(screenWidth()) - ballSize, pos#x);
    Assert.assertTrue(vel#x < 0.0f32)

// (50,5) + vel(0,-10) * 1.0 = (50,-5) -> 上の壁で y=0 に止まり、vy が逆向きになる
@Test
def testPhysicsStepBallTopWall(): Unit \ Assert =
    let state = mkTestState(10.0f32, 200.0f32, 50.0f32, 5.0f32, 0.0f32, -10.0f32, false);
    let newRoot = testAdvancePhysics(state#scene, 1.0f32, {x = 10.0f32, y = 200.0f32});
    let result = {scene = newRoot | state};
    let pos = (BreakoutScene.ballSnapshot(result#scene))#pos;
    let vel = (BreakoutScene.ballSnapshot(result#scene))#vel;
    Assert.assertEq(expected = 0.0f32, pos#y);
    Assert.assertTrue(vel#y > 0.0f32)

// --- checkDeathZone (replaces checkBallReset tests) ---

@Test
def testCheckDeathZoneInBounds(): Unit \ Assert =
    let state = mkTestState(10.0f32, 200.0f32, 40.0f32, 30.0f32, 10.0f32, -35.0f32, false);
    let pos = (BreakoutScene.ballSnapshot(state#scene))#pos;
    Assert.assertEq(expected = 40.0f32, pos#x);
    Assert.assertEq(expected = 30.0f32, pos#y);
    Assert.assertFalse((BreakoutScene.ballSnapshot(state#scene))#stuck)

// --- processInput ---

def withMockInput(pressedKeys: Set[Int32], f: Unit -> a \ ef): a \ ef - Game.Game =
    run { f() } with handler Game.Game {
        def getInitialState(_, _k) = bug!("not used in test")
        def render(_, resume) = resume(())
        def shouldClose(_, resume) = resume(true)
        def getDeltaTime(_, resume) = resume(0.0f32)
        def isKeyPressed(keyCode, resume) = resume(Set.memberOf(keyCode, pressedKeys))
    }

@Test
def testProcessInputSetsPaddleVelocityLeft(): Unit \ Assert =
    let state = mkTestState(10.0f32, 50.0f32, 30.0f32, 20.0f32, 10.0f32, -35.0f32, false);
    let result = run { processInput(state) } with withMockInput(Set#{keyA()});
    let paddleNode = SceneTree.findNode("Paddle", result#scene);
    let velX = paddleNode
        |> Option.flatMap(SceneTree.kinematicBodyData)
        |> Option.map(bd -> bd#velocity#x);
    Assert.assertTrue(Option.getWithDefault(0.0f32, velX) < 0.0f32)

@Test
def testProcessInputSetsPaddleVelocityRight(): Unit \ Assert =
    let state = mkTestState(10.0f32, 50.0f32, 30.0f32, 20.0f32, 10.0f32, -35.0f32, false);
    let result = run { processInput(state) } with withMockInput(Set#{keyD()});
    let paddleNode = SceneTree.findNode("Paddle", result#scene);
    let velX = paddleNode
        |> Option.flatMap(SceneTree.kinematicBodyData)
        |> Option.map(bd -> bd#velocity#x);
    Assert.assertTrue(Option.getWithDefault(0.0f32, velX) > 0.0f32)

@Test
def testProcessInputLaunchBall(): Unit \ Assert =
    let state = mkTestState(10.0f32, 50.0f32, 30.0f32, 20.0f32, 10.0f32, -35.0f32, true);
    let result = run { processInput(state) } with withMockInput(Set#{keySpace()});
    Assert.assertFalse((BreakoutScene.ballSnapshot(result#scene))#stuck)

// --- tickShake ---

@Test
def testTickShakeDecay(): Unit \ Assert =
    let state = mkTestStateWithShake(10.0f32, 50.0f32, 30.0f32, 20.0f32, 10.0f32, -35.0f32, true, 0.15f32);
    let result = tickShake(0.05f32, state);
    Assert.assertTrue(result#shakeTime > 0.09f32 and result#shakeTime < 0.11f32)

@Test
def testTickShakeClampToZero(): Unit \ Assert =
    let state = mkTestStateWithShake(10.0f32, 50.0f32, 30.0f32, 20.0f32, 10.0f32, -35.0f32, true, 0.02f32);
    let result = tickShake(0.05f32, state);
    Assert.assertEq(expected = 0.0f32, result#shakeTime)

@Test
def testTickShakeAlreadyZero(): Unit \ Assert =
    let state = mkTestState(10.0f32, 50.0f32, 30.0f32, 20.0f32, 10.0f32, -35.0f32, true);
    let result = tickShake(0.016f32, state);
    Assert.assertEq(expected = 0.0f32, result#shakeTime)

// --- Collision test helpers ---

def mkBrickTemplate(pos: Vec2D.Vec2, size: Vec2D.Vec2, isSolid: Bool): Game.BrickTemplate =
    {position = pos, size = size,
     color = {r = 1.0f32, g = 1.0f32, b = 1.0f32},
     isSolid = isSolid,
     texture = if (isSolid) "block_solid" else "block"}

def mkTestStateWithBricks(
    px: Float32, py: Float32,
    bx: Float32, by: Float32,
    vx: Float32, vy: Float32,
    stuck: Bool,
    bricks: List[Game.BrickTemplate]
): Game.GameState =
    let level: Game.LevelData = {bricks = bricks};
    let scene = BreakoutScene.buildInitialScene(screenWidth(), screenHeight(), level)
        |> SceneTree.setNodePosition("Paddle", {x = px, y = py})
        |> SceneTree.setNodePosition("Ball", {x = bx, y = by})
        |> BreakoutScene.updateBall(_ -> {velocity = {x = vx, y = vy}, stuck = stuck});
    {scene = scene, levels = Nil, currentLevel = 0, shakeTime = 0.0f32,
     powerUpsInField = Map.empty(), powerUpCounter = 0, activeEffects = Nil}

// --- applyCollisions helper (handles Math.Random with seed) ---

def testApplyCollisions(dt: Float32, screenSize: Vec2D.Vec2, state: Game.GameState): Game.GameState =
    run { applyCollisions(dt, screenSize, state) } with Math.Random.runWithSeed(42i64)

// --- applyCollisions tests ---

// ボールが下に飛んでパドルに当たる。
// 跳ね返る向きは「ボール中心 - パドル中心」で決まる:
//   normalize((92.5,70.5) - (100,90)) = normalize(-7.5, -19.5)
//   → vy が負(上向き)になる
// 速さはそのまま、向きだけ変わる。
//
//       50       80  105     150
//  y=58 .........+----+..........
//       .........| () |..........  ボール
//  y=80 +-------[当たり]------+  vel(10,35) 下向き
//       |      パドル         |
//  y=83 .........+----+..........
//       |                     |
// y=100 +---------------------+
//
@Test
def testApplyCollisionsBallHitsPaddleRedirectsVelocity(): Unit \ Assert =
    let state = mkTestState(50.0f32, 80.0f32, 80.0f32, 58.0f32, 10.0f32, 35.0f32, false);
    let result = testApplyCollisions(0.001f32, testScreenSize(), state);
    let vy = (BreakoutScene.ballSnapshot(result#scene))#vel#y;
    Assert.assertTrue(vy < 0.0f32)

@Test
def testApplyCollisionsBallHitsPaddlePreservesSpeed(): Unit \ Assert =
    let state = mkTestState(50.0f32, 80.0f32, 80.0f32, 58.0f32, 10.0f32, 35.0f32, false);
    let speedBefore = Vec2D.length({x = 10.0f32, y = 35.0f32});
    let result = testApplyCollisions(0.001f32, testScreenSize(), state);
    let vel = (BreakoutScene.ballSnapshot(result#scene))#vel;
    let speedAfter = Vec2D.length(vel);
    let diff = Float32.abs(speedAfter - speedBefore);
    Assert.assertTrue(diff < 1.0f32)

// ボールが下に飛んでブリックに当たる。
// パドルは (200,200) に置いて、ここでは関係しないようにする。
//
//     10  37.5  62.5  90
// y=-7 ....+-----+.....
//     ....| ()  |.....  ボール
// y=10 +--[当たり]--+
//     |  ブリック   |
// y=18 ....+-----+.....
//     |             |
// y=30 +------------+
//
// 壊れるブリック   -> destroyed=true
// 壊れないブリック -> shakeTime=0.15, destroyed=false
//
@Test
def testApplyCollisionsBallHitsNonSolidBrickDestroys(): Unit \ Assert =
    let brick = mkBrickTemplate({x = 10.0f32, y = 10.0f32}, {x = 80.0f32, y = 20.0f32}, false);
    let state = mkTestStateWithBricks(200.0f32, 200.0f32, 37.5f32, -7.0f32, 0.0f32, 35.0f32, false, brick :: Nil);
    let result = testApplyCollisions(0.001f32, testScreenSize(), state);
    let brickNode = SceneTree.findNode("Brick_0", result#scene);
    let destroyed = brickNode |> Option.flatMap(SceneTree.staticBodyData) |> Option.map(bd -> bd#destroyed);
    Assert.assertEq(expected = Some(true), destroyed)

@Test
def testApplyCollisionsBallHitsSolidBrickSetsShake(): Unit \ Assert =
    let brick = mkBrickTemplate({x = 10.0f32, y = 10.0f32}, {x = 80.0f32, y = 20.0f32}, true);
    let state = mkTestStateWithBricks(200.0f32, 200.0f32, 37.5f32, -7.0f32, 0.0f32, 35.0f32, false, brick :: Nil);
    let result = testApplyCollisions(0.001f32, testScreenSize(), state);
    Assert.assertEq(expected = 0.15f32, result#shakeTime)

@Test
def testApplyCollisionsBallHitsSolidBrickNotDestroyed(): Unit \ Assert =
    let brick = mkBrickTemplate({x = 10.0f32, y = 10.0f32}, {x = 80.0f32, y = 20.0f32}, true);
    let state = mkTestStateWithBricks(200.0f32, 200.0f32, 37.5f32, -7.0f32, 0.0f32, 35.0f32, false, brick :: Nil);
    let result = testApplyCollisions(0.001f32, testScreenSize(), state);
    let brickNode = SceneTree.findNode("Brick_0", result#scene);
    let destroyed = brickNode |> Option.flatMap(SceneTree.staticBodyData) |> Option.map(bd -> bd#destroyed);
    Assert.assertEq(expected = Some(false), destroyed)

// ボールが画面の下に落ちてデスゾーンに入る。
// → パドルにくっつき直す(stuck=true)、速度も初期値に戻る。
// パドルは (200,200) に置いて、ここでは当たらないようにする。
//
//      0   50  75                800
// y=585 ....+--+..................
//      ....| O|..................  ボール
// y=600 ====[==]==================  デスゾーン
//      ====|  |==================
// y=610 ....+--+..................
//      ============================
// y=620 ============================
//
@Test
def testApplyCollisionsBallEntersDeathZoneResetsStuck(): Unit \ Assert =
    let state = mkTestState(200.0f32, 200.0f32, 50.0f32, 585.0f32, 10.0f32, 35.0f32, false);
    let result = testApplyCollisions(0.001f32, testScreenSize(), state);
    Assert.assertTrue((BreakoutScene.ballSnapshot(result#scene))#stuck)

@Test
def testApplyCollisionsBallEntersDeathZoneResetsVelocity(): Unit \ Assert =
    let state = mkTestState(200.0f32, 200.0f32, 50.0f32, 585.0f32, 10.0f32, 35.0f32, false);
    let result = testApplyCollisions(0.001f32, testScreenSize(), state);
    let vel = (BreakoutScene.ballSnapshot(result#scene))#vel;
    Assert.assertEq(expected = initialBallVelocityX(), vel#x);
    Assert.assertEq(expected = initialBallVelocityY(), vel#y)

// 上のブリックのテストと同じ配置だけど、ボールはパドルにくっついている(stuck=true)。
// くっついているボールは当たり判定をしないので、ブリックは壊れない。
@Test
def testApplyCollisionsStuckBallNoEvents(): Unit \ Assert =
    let brick = mkBrickTemplate({x = 10.0f32, y = 10.0f32}, {x = 80.0f32, y = 20.0f32}, false);
    let state = mkTestStateWithBricks(200.0f32, 200.0f32, 37.5f32, -7.0f32, 0.0f32, 35.0f32, true, brick :: Nil);
    let result = testApplyCollisions(0.001f32, testScreenSize(), state);
    let brickNode = SceneTree.findNode("Brick_0", result#scene);
    let destroyed = brickNode |> Option.flatMap(SceneTree.staticBodyData) |> Option.map(bd -> bd#destroyed);
    Assert.assertEq(expected = Some(false), destroyed)

// ========================================================================
// PowerUp Tests
// ========================================================================

// --- PowerUp helpers ---

// 各パワーアップタイプごとに色が決まっている。Speed は青系 (0.5, 0.5, 1.0)。
@Test
def testPowerUpColorSpeed(): Unit \ Assert =
    let c = Game.powerUpColor(Game.PowerUpType.Speed);
    Assert.assertEq(expected = 0.5f32, c#r);
    Assert.assertEq(expected = 0.5f32, c#g);
    Assert.assertEq(expected = 1.0f32, c#b)

// 持続時間: Sticky は 20 秒、Speed は永続 (duration=0)。
@Test
def testPowerUpDurationSticky(): Unit \ Assert =
    Assert.assertEq(expected = 20.0f32, Game.powerUpDuration(Game.PowerUpType.Sticky))

@Test
def testPowerUpDurationSpeedPermanent(): Unit \ Assert =
    Assert.assertEq(expected = 0.0f32, Game.powerUpDuration(Game.PowerUpType.Speed))

// makePowerUp はタイプと位置からパワーアップ情報を生成する。
// サイズは固定 (60x20)、落下速度は 150。
@Test
def testMakePowerUp(): Unit \ Assert =
    let pu = Game.makePowerUp(Game.PowerUpType.Sticky, {x = 100.0f32, y = 200.0f32});
    Assert.assertEq(expected = Game.PowerUpType.Sticky, pu#powerUpType);
    Assert.assertEq(expected = 100.0f32, pu#position#x);
    Assert.assertEq(expected = 60.0f32, pu#size#x);
    Assert.assertEq(expected = 20.0f32, pu#size#y);
    Assert.assertEq(expected = 150.0f32, pu#velocity#y)

// --- isEffectActive ---

// activeEffects リストに指定タイプが含まれていれば true、なければ false。
@Test
def testIsEffectActiveTrue(): Unit \ Assert =
    let effects: List[Game.ActiveEffect] =
        {powerUpType = Game.PowerUpType.Sticky, remainingTime = 10.0f32} :: Nil;
    Assert.assertTrue(Game.isEffectActive(Game.PowerUpType.Sticky, effects))

// 空リストなら常に false。
@Test
def testIsEffectActiveFalse(): Unit \ Assert =
    let effects: List[Game.ActiveEffect] = Nil;
    Assert.assertFalse(Game.isEffectActive(Game.PowerUpType.Sticky, effects))

// --- Scene-tree based PowerUp tests ---

// Helper: add a powerup node to the scene and metadata map
def addTestPowerUp(name: String, powerUp: Game.PowerUpInfo, state: Game.GameState): Game.GameState =
    let powerUpNode = BreakoutScene.buildPowerUpNode(name, powerUp);
    let meta: Game.FieldPowerUp = {powerUpType = powerUp#powerUpType, duration = powerUp#duration};
    let newScene = BreakoutScene.addPowerUpToField(powerUpNode, state#scene);
    {scene = newScene,
     powerUpsInField = Map.insert(name, meta, state#powerUpsInField),
     powerUpCounter = state#powerUpCounter + 1 | state}

// パワーアップノードは Area で、velocity.y=150 で落下する。
// dt=1.0 で y=100 → y=250 に移動する。
//
//  y=100 +------+
//        |Speed |  ← 初期位置
//  y=120 +------+
//        |      |
//        v 150/s
//  y=250 +------+
//        |Speed |  ← 1秒後
//  y=270 +------+
//
@Test
def testPowerUpNodeMoveDown(): Unit \ Assert =
    let powerUp = Game.makePowerUp(Game.PowerUpType.Speed, {x = 100.0f32, y = 100.0f32});
    let state = mkTestState(350.0f32, 580.0f32, 400.0f32, 555.0f32, 100.0f32, -350.0f32, true);
    let stateWithPowerUp = addTestPowerUp("PowerUp_0", powerUp, state);
    let movedScene = testAdvancePhysics(stateWithPowerUp#scene, 1.0f32, {x = 350.0f32, y = 580.0f32});
    match BreakoutScene.getFieldPowerUps(movedScene) |> List.head {
        case Some(node) => Assert.assertEq(expected = 250.0f32, SceneTree.nodePosition(node)#y)
        case None => Assert.assertTrue(false)
    }

// DeathZone (y=600) と重なったパワーアップはシーンとメタデータの両方から除去される。
@Test
def testPowerUpNodeOffScreenRemoved(): Unit \ Assert =
    // Place powerup at y=600 to overlap with DeathZone (at y=600, size 800x20)
    let powerUp = Game.makePowerUp(Game.PowerUpType.Speed, {x = 100.0f32, y = 600.0f32});
    let state = mkTestState(350.0f32, 580.0f32, 400.0f32, 555.0f32, 100.0f32, -350.0f32, true);
    let stateWithPowerUp = addTestPowerUp("PowerUp_0", powerUp, state);
    let result = testApplyCollisions(0.001f32, testScreenSize(), stateWithPowerUp);
    Assert.assertEq(expected = 0, List.length(BreakoutScene.getFieldPowerUps(result#scene)));
    Assert.assertEq(expected = 0, Map.size(result#powerUpsInField))

// パドルとパワーアップが重なると収集される。
// 収集後: シーンからノード削除、メタデータ削除、効果が即時発動。
// Speed の場合はボール速度が 1.2 倍になる (100 → 120)。
//
//     350       370  430     450
// y=575 ........+----+.........
//       ........|PwUp|.........  パワーアップ (60x20)
// y=580 +------[重なり]-----+
//       |      パドル       |  (100x20)
// y=595 ........+----+.........
//       |                   |
// y=600 +-------------------+
//
@Test
def testPowerUpPaddleCollision(): Unit \ Assert =
    // Place powerup overlapping with paddle (paddle at 350,580 size 100x20, powerup at 370,575 size 60x20)
    let powerUp = Game.makePowerUp(Game.PowerUpType.Speed, {x = 370.0f32, y = 575.0f32});
    let state = mkTestState(350.0f32, 580.0f32, 400.0f32, 400.0f32, 100.0f32, -350.0f32, false);
    let stateWithPowerUp = addTestPowerUp("PowerUp_0", powerUp, state);
    let result = testApplyCollisions(0.001f32, testScreenSize(), stateWithPowerUp);
    // Powerup should be collected and removed
    Assert.assertEq(expected = 0, List.length(BreakoutScene.getFieldPowerUps(result#scene)));
    Assert.assertEq(expected = 0, Map.size(result#powerUpsInField));
    // Speed powerup should have increased ball velocity
    let vel = (BreakoutScene.ballSnapshot(result#scene))#vel;
    Assert.assertTrue(Float32.abs(vel#x - 120.0f32) < 0.01f32)

// --- updateActiveEffects ---

// dt 分だけ remainingTime が減り、0 以下になったエフェクトはリストから消える。
@Test
def testUpdateActiveEffectsDecay(): Unit \ Assert =
    let effects: List[Game.ActiveEffect] =
        {powerUpType = Game.PowerUpType.Sticky, remainingTime = 10.0f32} :: Nil;
    let state = {activeEffects = effects | mkTestState(350.0f32, 580.0f32, 400.0f32, 555.0f32, 100.0f32, -350.0f32, true)};
    let result = Game.updateActiveEffects(1.0f32, state);
    match List.head(result#activeEffects) {
        case Some(effect) => Assert.assertEq(expected = 9.0f32, effect#remainingTime)
        case None => Assert.assertTrue(false)
    }

// remainingTime=0.5 に dt=1.0 → 残り -0.5 → リストから除去。
@Test
def testUpdateActiveEffectsExpire(): Unit \ Assert =
    let effects: List[Game.ActiveEffect] =
        {powerUpType = Game.PowerUpType.Sticky, remainingTime = 0.5f32} :: Nil;
    let state = {activeEffects = effects | mkTestState(350.0f32, 580.0f32, 400.0f32, 555.0f32, 100.0f32, -350.0f32, true)};
    let result = Game.updateActiveEffects(1.0f32, state);
    Assert.assertEq(expected = 0, List.length(result#activeEffects))

// --- activatePowerUp ---

// Speed パワーアップ: ボール速度が 1.2 倍になる。
// vel(100, -350) → vel(120, -420)
@Test
def testActivatePowerUpSpeedIncreasesBallVelocity(): Unit \ Assert =
    let meta: Game.FieldPowerUp = {powerUpType = Game.PowerUpType.Speed, duration = 0.0f32};
    let state = mkTestState(350.0f32, 580.0f32, 400.0f32, 400.0f32, 100.0f32, -350.0f32, false);
    let result = Game.activatePowerUp(meta, state);
    let vel = (BreakoutScene.ballSnapshot(result#scene))#vel;
    Assert.assertTrue(Float32.abs(vel#x - 120.0f32) < 0.01f32);
    Assert.assertTrue(Float32.abs(vel#y - (-420.0f32)) < 0.01f32)

// PadSizeIncrease パワーアップ: パドル幅が 100 → 150 になる。
@Test
def testActivatePowerUpPadSizeIncrease(): Unit \ Assert =
    let meta: Game.FieldPowerUp = {powerUpType = Game.PowerUpType.PadSizeIncrease, duration = 0.0f32};
    let state = mkTestState(350.0f32, 580.0f32, 400.0f32, 400.0f32, 100.0f32, -350.0f32, false);
    let result = Game.activatePowerUp(meta, state);
    let paddle = BreakoutScene.paddleSnapshot(result#scene);
    Assert.assertEq(expected = 150.0f32, paddle#size#x)

// --- Death zone resets powerups ---

// デスゾーン突入で全パワーアップがリセットされる:
// - powerUpsInField (未収集ノードの管理マップ) → 空
// - activeEffects (発動中の効果リスト) → 空
// - シーン上のパワーアップノード → 全削除
@Test
def testDeathZoneResetsPowerUps(): Unit \ Assert =
    let effects: List[Game.ActiveEffect] =
        {powerUpType = Game.PowerUpType.Sticky, remainingTime = 10.0f32} :: Nil;
    let state0 = mkTestState(200.0f32, 200.0f32, 50.0f32, 585.0f32, 10.0f32, 35.0f32, false);
    let powerUp = Game.makePowerUp(Game.PowerUpType.Speed, {x = 100.0f32, y = 100.0f32});
    let state1 = addTestPowerUp("PowerUp_0", powerUp, state0);
    let state = {activeEffects = effects | state1};
    let result = testApplyCollisions(0.001f32, testScreenSize(), state);
    Assert.assertEq(expected = 0, Map.size(result#powerUpsInField));
    Assert.assertEq(expected = 0, List.length(result#activeEffects));
    Assert.assertEq(expected = 0, List.length(BreakoutScene.getFieldPowerUps(result#scene)))
