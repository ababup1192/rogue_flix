// Tests for SceneTree — coordinate accumulation, draw order, utilities, and engine

use SceneTree.{collectDrawables,
               node2D, sprite2D, collisionShape2D, kinematicBody2D, staticBody2D, rigidBody2D, area2D}

def mkSpriteData(tex: String): SceneTree.SpriteData =
    {size = {x = 10.0f32, y = 10.0f32}, color = {r = 1.0f32, g = 1.0f32, b = 1.0f32}, texture = tex, visible = true}

def mkPos(px: Float32, py: Float32): Vec2D.Vec2 =
    {x = px, y = py}

// --- 座標加算 ---

@Test
def testPositionAccumulation(): Unit \ Assert =
    let node = node2D("Parent", mkPos(100.0f32, 50.0f32),
        sprite2D("Child", mkPos(10.0f32, 5.0f32), mkSpriteData("block")) :: Nil
    );
    let result = collectDrawables(node, {x = 0.0f32, y = 0.0f32});
    let posX = List.head(result) |> Option.map(match (_, p) -> p#x);
    let posY = List.head(result) |> Option.map(match (_, p) -> p#y);
    Assert.assertEq(expected = Some(110.0f32), posX);
    Assert.assertEq(expected = Some(55.0f32), posY)

@Test
def testNestedPositionAccumulation(): Unit \ Assert =
    let leaf = sprite2D("Leaf", mkPos(5.0f32, 5.0f32), mkSpriteData("ball"));
    let inner = node2D("Inner", mkPos(20.0f32, 30.0f32), leaf :: Nil);
    let outer = node2D("Outer", mkPos(100.0f32, 200.0f32), inner :: Nil);
    let result = collectDrawables(outer, {x = 1.0f32, y = 2.0f32});
    let posX = List.head(result) |> Option.map(match (_, p) -> p#x);
    let posY = List.head(result) |> Option.map(match (_, p) -> p#y);
    Assert.assertEq(expected = Some(126.0f32), posX);
    Assert.assertEq(expected = Some(237.0f32), posY)

@Test
def testInvisibleSpriteSkipped(): Unit \ Assert =
    let sd = {size = {x = 10.0f32, y = 10.0f32}, color = {r = 1.0f32, g = 1.0f32, b = 1.0f32}, texture = "block", visible = false};
    let node = sprite2D("Hidden", Vec2D.zero(), sd);
    let result = collectDrawables(node, {x = 0.0f32, y = 0.0f32});
    Assert.assertEq(expected = 0, List.length(result))

// --- 描画順序 ---

@Test
def testDrawOrder(): Unit \ Assert =
    let node = node2D("Root", Vec2D.zero(),
        sprite2D("BG", Vec2D.zero(), mkSpriteData("background")) ::
        sprite2D("Block", Vec2D.zero(), mkSpriteData("block")) ::
        sprite2D("Paddle", Vec2D.zero(), mkSpriteData("paddle")) ::
        Nil
    );
    let textures = collectDrawables(node, {x = 0.0f32, y = 0.0f32})
        |> List.map(match (sd, _) -> sd#texture);
    Assert.assertEq(expected = "background" :: "block" :: "paddle" :: Nil, textures)

@Test
def testDrawOrderWithNestedGroup(): Unit \ Assert =
    let bricks = node2D("Bricks", Vec2D.zero(),
        sprite2D("B1", Vec2D.zero(), mkSpriteData("block")) ::
        sprite2D("B2", Vec2D.zero(), mkSpriteData("block_solid")) ::
        Nil
    );
    let root = node2D("Root", Vec2D.zero(),
        sprite2D("BG", Vec2D.zero(), mkSpriteData("background")) ::
        bricks ::
        sprite2D("Paddle", Vec2D.zero(), mkSpriteData("paddle")) ::
        Nil
    );
    let textures = collectDrawables(root, {x = 0.0f32, y = 0.0f32})
        |> List.map(match (sd, _) -> sd#texture);
    Assert.assertEq(expected = "background" :: "block" :: "block_solid" :: "paddle" :: Nil, textures)

// --- destroyed StaticBody2D のスキップ ---

@Test
def testDestroyedStaticBodySkipped(): Unit \ Assert =
    let brick = staticBody2D("Brick", mkPos(10.0f32, 10.0f32),
        {isSolid = false, destroyed = true},
        sprite2D("BrickSprite", Vec2D.zero(), mkSpriteData("block")) :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), brick :: Nil);
    let result = collectDrawables(root, Vec2D.zero());
    Assert.assertEq(expected = 0, List.length(result))

// --- KinematicBody2D の子Spriteが描画される ---

@Test
def testKinematicBodyChildDrawable(): Unit \ Assert =
    let paddle = kinematicBody2D("Paddle", mkPos(100.0f32, 200.0f32),
        {velocity = Vec2D.zero()},
        sprite2D("PaddleSprite", Vec2D.zero(), mkSpriteData("paddle")) :: Nil
    );
    let result = collectDrawables(paddle, Vec2D.zero());
    Assert.assertEq(expected = 1, List.length(result));
    let posX = List.head(result) |> Option.map(match (_, p) -> p#x);
    Assert.assertEq(expected = Some(100.0f32), posX)

// --- findNode ---

@Test
def testFindNodeRoot(): Unit \ Assert =
    let root = node2D("Root", Vec2D.zero(), Nil);
    let found = SceneTree.findNode("Root", root) |> Option.map(SceneTree.nodeName);
    Assert.assertEq(expected = Some("Root"), found)

@Test
def testFindNodeNested(): Unit \ Assert =
    let child = sprite2D("Ball", Vec2D.zero(), mkSpriteData("ball"));
    let root = node2D("Root", Vec2D.zero(), child :: Nil);
    let found = SceneTree.findNode("Ball", root) |> Option.map(SceneTree.nodeName);
    Assert.assertEq(expected = Some("Ball"), found)

@Test
def testFindNodeMissing(): Unit \ Assert =
    let root = node2D("Root", Vec2D.zero(), Nil);
    let found = SceneTree.findNode("Missing", root);
    Assert.assertTrue(Option.isEmpty(found))

// --- mapNode ---

@Test
def testMapNodeModifiesTarget(): Unit \ Assert =
    let root = node2D("Root", Vec2D.zero(),
        sprite2D("Ball", mkPos(10.0f32, 20.0f32), mkSpriteData("ball")) :: Nil
    );
    let updated = SceneTree.mapNode("Ball", _ ->
        sprite2D("Ball", mkPos(99.0f32, 99.0f32), mkSpriteData("ball")),
        root
    );
    let pos = SceneTree.globalPosition("Ball", updated);
    let px = pos |> Option.map(p -> p#x);
    Assert.assertEq(expected = Some(99.0f32), px)

// --- globalPosition ---

@Test
def testGlobalPositionNested(): Unit \ Assert =
    let child = sprite2D("Ball", mkPos(10.0f32, 20.0f32), mkSpriteData("ball"));
    let parent = node2D("Root", mkPos(100.0f32, 200.0f32), child :: Nil);
    let pos = SceneTree.globalPosition("Ball", parent);
    let px = pos |> Option.map(p -> p#x);
    let py = pos |> Option.map(p -> p#y);
    Assert.assertEq(expected = Some(110.0f32), px);
    Assert.assertEq(expected = Some(220.0f32), py)

// --- vectorDirection ---

@Test
def testVectorDirectionUp(): Unit \ Assert =
    Assert.assertEq(expected = SceneTree.Direction.Up, SceneTree.vectorDirection({x = 0.0f32, y = 5.0f32}))

@Test
def testVectorDirectionRight(): Unit \ Assert =
    Assert.assertEq(expected = SceneTree.Direction.Right, SceneTree.vectorDirection({x = 5.0f32, y = 0.0f32}))

@Test
def testVectorDirectionDown(): Unit \ Assert =
    Assert.assertEq(expected = SceneTree.Direction.Down, SceneTree.vectorDirection({x = 0.0f32, y = -5.0f32}))

@Test
def testVectorDirectionLeft(): Unit \ Assert =
    Assert.assertEq(expected = SceneTree.Direction.Left, SceneTree.vectorDirection({x = -5.0f32, y = 0.0f32}))

// --- checkCircleRect ---

@Test
def testCheckCircleRectNoHit(): Unit \ Assert =
    let result = SceneTree.checkCircleRect({x = 0.0f32, y = 0.0f32}, 12.5f32,
        {x = 100.0f32, y = 100.0f32}, {x = 50.0f32, y = 20.0f32});
    Assert.assertTrue(Option.isEmpty(result))

@Test
def testCheckCircleRectTopHit(): Unit \ Assert =
    let result = SceneTree.checkCircleRect({x = 112.5f32, y = 83.0f32}, 12.5f32,
        {x = 100.0f32, y = 100.0f32}, {x = 50.0f32, y = 20.0f32});
    let dir = result |> Option.map(match (d, _) -> d);
    Assert.assertTrue(not Option.isEmpty(result));
    Assert.assertEq(expected = Some(SceneTree.Direction.Up), dir)

@Test
def testCheckCircleRectLeftHit(): Unit \ Assert =
    let result = SceneTree.checkCircleRect({x = 78.0f32, y = 97.5f32}, 12.5f32,
        {x = 100.0f32, y = 100.0f32}, {x = 50.0f32, y = 20.0f32});
    let dir = result |> Option.map(match (d, _) -> d);
    Assert.assertEq(expected = Some(SceneTree.Direction.Right), dir)

@Test
def testCheckCircleRectRightHit(): Unit \ Assert =
    let result = SceneTree.checkCircleRect({x = 148.0f32, y = 97.5f32}, 12.5f32,
        {x = 100.0f32, y = 100.0f32}, {x = 50.0f32, y = 20.0f32});
    let dir = result |> Option.map(match (d, _) -> d);
    Assert.assertEq(expected = Some(SceneTree.Direction.Left), dir)

@Test
def testCheckCircleRectBottomHit(): Unit \ Assert =
    let result = SceneTree.checkCircleRect({x = 112.5f32, y = 117.0f32}, 12.5f32,
        {x = 100.0f32, y = 100.0f32}, {x = 50.0f32, y = 20.0f32});
    let dir = result |> Option.map(match (d, _) -> d);
    Assert.assertEq(expected = Some(SceneTree.Direction.Down), dir)

@Test
def testCheckCircleRectBarelyMiss(): Unit \ Assert =
    let result = SceneTree.checkCircleRect({x = 112.5f32, y = 74.9f32}, 12.5f32,
        {x = 100.0f32, y = 100.0f32}, {x = 50.0f32, y = 20.0f32});
    Assert.assertTrue(Option.isEmpty(result))

// --- resolveCollision ---

@Test
def testResolveCollisionHorizontal(): Unit \ Assert =
    let (newPos, newVel) = SceneTree.resolveCollision(
        {x = 100.0f32, y = 100.0f32}, {x = 200.0f32, y = -300.0f32}, 12.5f32,
        SceneTree.Direction.Left, {x = -5.0f32, y = 0.0f32});
    Assert.assertTrue(newPos#x > 100.0f32);
    Assert.assertTrue(newVel#x < 0.0f32);
    Assert.assertEq(expected = -300.0f32, newVel#y)

@Test
def testResolveCollisionVertical(): Unit \ Assert =
    let (newPos, newVel) = SceneTree.resolveCollision(
        {x = 100.0f32, y = 100.0f32}, {x = 200.0f32, y = -300.0f32}, 12.5f32,
        SceneTree.Direction.Up, {x = 0.0f32, y = -5.0f32});
    Assert.assertTrue(newPos#y < 100.0f32);
    Assert.assertEq(expected = 200.0f32, newVel#x);
    Assert.assertTrue(newVel#y > 0.0f32)

// --- collectBodies ---

@Test
def testCollectBodiesStaticBody(): Unit \ Assert =
    let brick = staticBody2D("Brick_0", mkPos(50.0f32, 50.0f32),
        {isSolid = false, destroyed = false},
        collisionShape2D("BrickCollider_0", SceneTree.CollisionShapeData.RectShape({x = 80.0f32, y = 20.0f32})) :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), brick :: Nil);
    let bodies = SceneTree.collectBodies(root);
    Assert.assertEq(expected = 1, List.length(bodies));
    let name = List.head(bodies) |> Option.map(b -> b#name);
    Assert.assertEq(expected = Some("Brick_0"), name)

@Test
def testCollectBodiesSkipsDestroyed(): Unit \ Assert =
    let brick = staticBody2D("Brick_0", mkPos(50.0f32, 50.0f32),
        {isSolid = false, destroyed = true},
        collisionShape2D("BrickCollider_0", SceneTree.CollisionShapeData.RectShape({x = 80.0f32, y = 20.0f32})) :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), brick :: Nil);
    let bodies = SceneTree.collectBodies(root);
    Assert.assertEq(expected = 0, List.length(bodies))

// --- physicsStep ---

@Test
def testPhysicsStepKinematicBody(): Unit \ Assert =
    let paddle = kinematicBody2D("Paddle", mkPos(100.0f32, 580.0f32),
        {velocity = {x = 500.0f32, y = 0.0f32}},
        collisionShape2D("PaddleCollider", SceneTree.CollisionShapeData.RectShape({x = 100.0f32, y = 20.0f32})) :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), paddle :: Nil);
    let config = {screenSize = {x = 800.0f32, y = 600.0f32}, anchorPos = {x = 100.0f32, y = 580.0f32}, anchorWidth = 100.0f32};
    let newRoot = run {
        SceneTree.stepAndCollide(root, 0.1f32, config)
    } with handler SceneTree.OnCollision {
        def bodyEntered(_, _, _, k) = k(())
        def areaEntered(_, _, _, k) = k(())
    };
    let pos = SceneTree.globalPosition("Paddle", newRoot);
    let px = pos |> Option.map(p -> p#x);
    Assert.assertEq(expected = Some(150.0f32), px)

@Test
def testPhysicsStepRigidBodyStuck(): Unit \ Assert =
    let paddle = kinematicBody2D("Paddle", mkPos(350.0f32, 580.0f32),
        {velocity = Vec2D.zero()},
        collisionShape2D("PaddleCollider", SceneTree.CollisionShapeData.RectShape({x = 100.0f32, y = 20.0f32})) :: Nil
    );
    let ball = rigidBody2D("Ball", mkPos(0.0f32, 0.0f32),
        {velocity = {x = 100.0f32, y = -350.0f32}, stuck = true},
        collisionShape2D("BallCollider", SceneTree.CollisionShapeData.CircleShape(12.5f32)) :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), paddle :: ball :: Nil);
    let config = {screenSize = {x = 800.0f32, y = 600.0f32}, anchorPos = {x = 350.0f32, y = 580.0f32}, anchorWidth = 100.0f32};
    let newRoot = run {
        SceneTree.stepAndCollide(root, 0.1f32, config)
    } with handler SceneTree.OnCollision {
        def bodyEntered(_, _, _, k) = k(())
        def areaEntered(_, _, _, k) = k(())
    };
    let pos = SceneTree.globalPosition("Ball", newRoot);
    let px = pos |> Option.map(p -> p#x);
    let expectedX = 350.0f32 + 100.0f32 / 2.0f32 - 12.5f32;
    Assert.assertEq(expected = Some(expectedX), px)

// --- updateKinematicBody ---

@Test
def testUpdateKinematicBody(): Unit \ Assert =
    let paddle = kinematicBody2D("Paddle", mkPos(100.0f32, 200.0f32),
        {velocity = Vec2D.zero()},
        Nil
    );
    let root = node2D("Root", Vec2D.zero(), paddle :: Nil);
    let updated = SceneTree.updateKinematicBody("Paddle",
        _ -> {velocity = {x = 500.0f32, y = 0.0f32}}, root);
    let vel = SceneTree.findNode("Paddle", updated)
        |> Option.flatMap(SceneTree.kinematicBodyData)
        |> Option.map(bd -> bd#velocity#x);
    Assert.assertEq(expected = Some(500.0f32), vel)

// --- updateRigidBody ---

@Test
def testUpdateRigidBody(): Unit \ Assert =
    let ball = rigidBody2D("Ball", mkPos(50.0f32, 50.0f32),
        {velocity = {x = 100.0f32, y = -200.0f32}, stuck = true},
        Nil
    );
    let root = node2D("Root", Vec2D.zero(), ball :: Nil);
    let updated = SceneTree.updateRigidBody("Ball",
        bd -> {stuck = false | bd}, root);
    let stuck = SceneTree.findNode("Ball", updated)
        |> Option.flatMap(SceneTree.rigidBodyData)
        |> Option.map(bd -> bd#stuck);
    Assert.assertEq(expected = Some(false), stuck)

// --- updateStaticBody ---

@Test
def testUpdateStaticBody(): Unit \ Assert =
    let brick = staticBody2D("Brick", mkPos(10.0f32, 10.0f32),
        {isSolid = false, destroyed = false},
        Nil
    );
    let root = node2D("Root", Vec2D.zero(), brick :: Nil);
    let updated = SceneTree.updateStaticBody("Brick",
        _ -> {isSolid = false, destroyed = true}, root);
    let found = SceneTree.findNode("Brick", updated);
    let destroyed = found |> Option.flatMap(SceneTree.staticBodyData)
        |> Option.map(bd -> bd#destroyed);
    Assert.assertEq(expected = Some(true), destroyed)

// --- setNodePosition ---

@Test
def testSetNodePosition(): Unit \ Assert =
    let child = sprite2D("Ball", mkPos(10.0f32, 20.0f32), mkSpriteData("ball"));
    let root = node2D("Root", Vec2D.zero(), child :: Nil);
    let updated = SceneTree.setNodePosition("Ball", {x = 99.0f32, y = 88.0f32}, root);
    let pos = SceneTree.globalPosition("Ball", updated);
    let px = pos |> Option.map(p -> p#x);
    let py = pos |> Option.map(p -> p#y);
    Assert.assertEq(expected = Some(99.0f32), px);
    Assert.assertEq(expected = Some(88.0f32), py)

// --- rigidBodyData ---

@Test
def testRigidBodyData(): Unit \ Assert =
    let ball = rigidBody2D("Ball", mkPos(50.0f32, 50.0f32),
        {velocity = {x = 100.0f32, y = -200.0f32}, stuck = true},
        Nil
    );
    let result = SceneTree.rigidBodyData(ball);
    let vel = result |> Option.map(bd -> bd#velocity#x);
    Assert.assertEq(expected = Some(100.0f32), vel)

@Test
def testRigidBodyDataNonRigid(): Unit \ Assert =
    let spriteNode = sprite2D("Ball", mkPos(0.0f32, 0.0f32), mkSpriteData("ball"));
    let result = SceneTree.rigidBodyData(spriteNode);
    Assert.assertTrue(Option.isEmpty(result))

// --- kinematicBodyData ---

@Test
def testKinematicBodyData(): Unit \ Assert =
    let paddle = kinematicBody2D("Paddle", mkPos(100.0f32, 200.0f32),
        {velocity = {x = 500.0f32, y = 0.0f32}},
        Nil
    );
    let result = SceneTree.kinematicBodyData(paddle);
    let vel = result |> Option.map(bd -> bd#velocity#x);
    Assert.assertEq(expected = Some(500.0f32), vel)

// --- findRectShape ---

@Test
def testFindRectShape(): Unit \ Assert =
    let children =
        sprite2D("Sprite", Vec2D.zero(), mkSpriteData("block")) ::
        collisionShape2D("Collider", SceneTree.CollisionShapeData.RectShape({x = 80.0f32, y = 20.0f32})) ::
        Nil;
    let result = SceneTree.findRectShape(children);
    let w = result |> Option.map(s -> s#x);
    Assert.assertEq(expected = Some(80.0f32), w)

@Test
def testFindRectShapeNone(): Unit \ Assert =
    let children = sprite2D("Sprite", Vec2D.zero(), mkSpriteData("block")) :: Nil;
    let result = SceneTree.findRectShape(children);
    Assert.assertTrue(Option.isEmpty(result))

// --- findCircleShape ---

@Test
def testFindCircleShape(): Unit \ Assert =
    let children =
        sprite2D("Sprite", Vec2D.zero(), mkSpriteData("ball")) ::
        collisionShape2D("Collider", SceneTree.CollisionShapeData.CircleShape(12.5f32)) ::
        Nil;
    let result = SceneTree.findCircleShape(children);
    Assert.assertEq(expected = Some(12.5f32), result)

@Test
def testFindCircleShapeNone(): Unit \ Assert =
    let children = sprite2D("Sprite", Vec2D.zero(), mkSpriteData("ball")) :: Nil;
    let result = SceneTree.findCircleShape(children);
    Assert.assertTrue(Option.isEmpty(result))

// --- detectCollisions ---

@Test
def testDetectCollisionsBallHitsBrick(): Unit \ Assert =
    let ball = rigidBody2D("Ball", mkPos(112.5f32, 83.0f32),
        {velocity = {x = 0.0f32, y = 100.0f32}, stuck = false},
        collisionShape2D("BallCollider", SceneTree.CollisionShapeData.CircleShape(12.5f32)) :: Nil
    );
    let brick = staticBody2D("Brick_0", mkPos(100.0f32, 100.0f32),
        {isSolid = false, destroyed = false},
        collisionShape2D("BrickCollider", SceneTree.CollisionShapeData.RectShape({x = 50.0f32, y = 20.0f32})) :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), ball :: brick :: Nil);
    let events = SceneTree.detectCollisions(root);
    Assert.assertEq(expected = 1, List.length(events));
    let targetName = List.head(events) |> Option.map(e -> e#targetName);
    Assert.assertEq(expected = Some("Brick_0"), targetName)

@Test
def testDetectCollisionsNoHit(): Unit \ Assert =
    let ball = rigidBody2D("Ball", mkPos(0.0f32, 0.0f32),
        {velocity = {x = 100.0f32, y = 100.0f32}, stuck = false},
        collisionShape2D("BallCollider", SceneTree.CollisionShapeData.CircleShape(12.5f32)) :: Nil
    );
    let brick = staticBody2D("Brick_0", mkPos(200.0f32, 200.0f32),
        {isSolid = false, destroyed = false},
        collisionShape2D("BrickCollider", SceneTree.CollisionShapeData.RectShape({x = 50.0f32, y = 20.0f32})) :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), ball :: brick :: Nil);
    let events = SceneTree.detectCollisions(root);
    Assert.assertEq(expected = 0, List.length(events))

@Test
def testDetectCollisionsStuckBallIgnored(): Unit \ Assert =
    let ball = rigidBody2D("Ball", mkPos(112.5f32, 83.0f32),
        {velocity = {x = 0.0f32, y = 100.0f32}, stuck = true},
        collisionShape2D("BallCollider", SceneTree.CollisionShapeData.CircleShape(12.5f32)) :: Nil
    );
    let brick = staticBody2D("Brick_0", mkPos(100.0f32, 100.0f32),
        {isSolid = false, destroyed = false},
        collisionShape2D("BrickCollider", SceneTree.CollisionShapeData.RectShape({x = 50.0f32, y = 20.0f32})) :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), ball :: brick :: Nil);
    let events = SceneTree.detectCollisions(root);
    Assert.assertEq(expected = 0, List.length(events))

@Test
def testDetectCollisionsAreaContainsNode(): Unit \ Assert =
    let ball = rigidBody2D("Ball", mkPos(112.5f32, 83.0f32),
        {velocity = {x = 0.0f32, y = 100.0f32}, stuck = false},
        collisionShape2D("BallCollider", SceneTree.CollisionShapeData.CircleShape(12.5f32)) :: Nil
    );
    let brick = staticBody2D("Brick_0", mkPos(100.0f32, 100.0f32),
        {isSolid = false, destroyed = false},
        collisionShape2D("BrickCollider", SceneTree.CollisionShapeData.RectShape({x = 50.0f32, y = 20.0f32})) :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), ball :: brick :: Nil);
    let events = SceneTree.detectCollisions(root);
    let areaName = List.head(events) |> Option.map(e -> SceneTree.nodeName(e#area));
    Assert.assertEq(expected = Some("Ball"), areaName)

// ========================================================================
// Node 特性テスト
// ========================================================================

// --- Node2D (Plain) ---
// 描画も物理データも持たない、純粋なコンテナノード。
// 自身の名前が子ノードの group になる（"Enemies" の下に並べれば全員 group="Enemies"）。
// 物理ステップで子ノードへ再帰するのは Node2D だけ。他のノードは自分自身を処理して終わる。

// Node2D の名前が、子ボディの group フィールドに伝搬する
@Test
def testNode2DGroupPropagation(): Unit \ Assert =
    let group = node2D("Enemies", Vec2D.zero(),
        staticBody2D("E1", mkPos(0.0f32, 0.0f32),
            {isSolid = false, destroyed = false},
            collisionShape2D("C1", SceneTree.CollisionShapeData.RectShape({x = 80.0f32, y = 20.0f32})) :: Nil
        ) ::
        staticBody2D("E2", mkPos(100.0f32, 0.0f32),
            {isSolid = false, destroyed = false},
            collisionShape2D("C2", SceneTree.CollisionShapeData.RectShape({x = 80.0f32, y = 20.0f32})) :: Nil
        ) ::
        Nil
    );
    let root = node2D("Root", Vec2D.zero(), group :: Nil);
    let bodies = SceneTree.collectBodies(root);
    let groups = List.map(b -> b#group, bodies);
    Assert.assertEq(expected = "Enemies" :: "Enemies" :: Nil, groups)

// Node2D 以外のノードは子ノードへ物理処理を再帰しない。
// KinematicBody2D の中に KinematicBody2D を入れても、内側の速度は適用されない。
@Test
def testNonPlainNodeDoesNotRecursePhysics(): Unit \ Assert =
    let innerKinematic = kinematicBody2D("Inner", mkPos(50.0f32, 50.0f32),
        {velocity = {x = 1000.0f32, y = 0.0f32}},
        Nil
    );
    let outerKinematic = kinematicBody2D("Outer", mkPos(100.0f32, 200.0f32),
        {velocity = Vec2D.zero()},
        innerKinematic :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), outerKinematic :: Nil);
    let config = {screenSize = {x = 800.0f32, y = 600.0f32}, anchorPos = Vec2D.zero(), anchorWidth = 100.0f32};
    let newRoot = run {
        SceneTree.stepAndCollide(root, 1.0f32, config)
    } with handler SceneTree.OnCollision {
        def bodyEntered(_, _, _, k) = k(())
        def areaEntered(_, _, _, k) = k(())
    };
    let innerPos = SceneTree.findNode("Inner", newRoot) |> Option.map(SceneTree.nodePosition);
    let px = innerPos |> Option.map(p -> p#x);
    Assert.assertEq(expected = Some(50.0f32), px)

// --- CollisionShape2D (Shape) ---
// 衝突判定の「形」を定義するノード（矩形 or 円）。
// 描画されることはない。見えない当たり判定。
// 必ずボディノード（Kinematic, Rigid, Static, Area）の子として配置する。

// Sprite と Shape を並べても、collectDrawables に入るのは Sprite だけ
@Test
def testCollisionShapeProducesNoDrawable(): Unit \ Assert =
    let root = node2D("Root", Vec2D.zero(),
        sprite2D("Vis", Vec2D.zero(), mkSpriteData("block")) ::
        collisionShape2D("Shape", SceneTree.CollisionShapeData.RectShape({x = 80.0f32, y = 20.0f32})) ::
        Nil
    );
    let result = collectDrawables(root, Vec2D.zero());
    Assert.assertEq(expected = 1, List.length(result))

// Shape を Node2D 直下に置いても collectBodies に含まれない（ボディではないため）
@Test
def testCollisionShapeNotCollectedAsBody(): Unit \ Assert =
    let root = node2D("Root", Vec2D.zero(),
        collisionShape2D("Shape", SceneTree.CollisionShapeData.RectShape({x = 80.0f32, y = 20.0f32})) ::
        Nil
    );
    let bodies = SceneTree.collectBodies(root);
    Assert.assertEq(expected = 0, List.length(bodies))

// --- KinematicBody2D (Kinematic) ---
// 外部入力で操作されるボディ。速度に従って移動する。
// 画面端でクランプされる（左端=0、右端=画面幅-自身の幅）。跳ね返りはしない。
// collectBodies では isSolid=true の「壊せない壁」として扱われる。

// 極端に大きな負の速度を与えても、X座標は 0 で止まる（画面外に出ない）
@Test
def testKinematicBodyStopsAtScreenEdge(): Unit \ Assert =
    let body = kinematicBody2D("Player", mkPos(100.0f32, 300.0f32),
        {velocity = {x = -10000.0f32, y = 0.0f32}},
        collisionShape2D("Collider", SceneTree.CollisionShapeData.RectShape({x = 100.0f32, y = 20.0f32})) :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), body :: Nil);
    let config = {screenSize = {x = 800.0f32, y = 600.0f32}, anchorPos = mkPos(100.0f32, 300.0f32), anchorWidth = 100.0f32};
    let newRoot = run {
        SceneTree.stepAndCollide(root, 0.1f32, config)
    } with handler SceneTree.OnCollision {
        def bodyEntered(_, _, _, k) = k(())
        def areaEntered(_, _, _, k) = k(())
    };
    let pos = SceneTree.globalPosition("Player", newRoot);
    let px = pos |> Option.map(p -> p#x);
    Assert.assertEq(expected = Some(0.0f32), px)

// collectBodies で KinematicBody2D は常に isSolid=true になる
@Test
def testKinematicBodyAlwaysSolid(): Unit \ Assert =
    let body = kinematicBody2D("Player", mkPos(100.0f32, 300.0f32),
        {velocity = Vec2D.zero()},
        collisionShape2D("Collider", SceneTree.CollisionShapeData.RectShape({x = 100.0f32, y = 20.0f32})) :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), body :: Nil);
    let bodies = SceneTree.collectBodies(root);
    Assert.assertEq(expected = 1, List.length(bodies));
    let solid = List.head(bodies) |> Option.map(b -> b#isSolid);
    Assert.assertEq(expected = Some(true), solid)

// --- RigidBody2D (Rigid) ---
// 速度で自律移動する物理ボディ。
// stuck=true: アンカー（KinematicBody2D）の上に固定される。衝突判定の対象外。
// stuck=false: 速度で飛び回り、画面の左壁・右壁・上壁で速度が反転する。
// collectBodies には含まれない（衝突の「発信者」であり「受信者」ではない）。
// collectRigidBodies にのみ含まれる。

// 左壁に衝突すると X=0 にクランプされ、X速度が正方向に反転する
@Test
def testRigidBodyReflectsOffLeftWall(): Unit \ Assert =
    let body = rigidBody2D("Projectile", mkPos(5.0f32, 300.0f32),
        {velocity = {x = -200.0f32, y = 0.0f32}, stuck = false},
        collisionShape2D("Collider", SceneTree.CollisionShapeData.CircleShape(12.5f32)) :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), body :: Nil);
    let config = {screenSize = {x = 800.0f32, y = 600.0f32}, anchorPos = Vec2D.zero(), anchorWidth = 100.0f32};
    let newRoot = run {
        SceneTree.stepAndCollide(root, 0.1f32, config)
    } with handler SceneTree.OnCollision {
        def bodyEntered(_, _, _, k) = k(())
        def areaEntered(_, _, _, k) = k(())
    };
    let pos = SceneTree.globalPosition("Projectile", newRoot);
    let px = pos |> Option.map(p -> p#x);
    Assert.assertEq(expected = Some(0.0f32), px);
    let vx = SceneTree.findNode("Projectile", newRoot)
        |> Option.flatMap(SceneTree.rigidBodyData)
        |> Option.map(bd -> bd#velocity#x)
        |> Option.getWithDefault(0.0f32);
    Assert.assertTrue(vx > 0.0f32)

// RigidBody2D は collectBodies には入らず、collectRigidBodies にだけ入る
@Test
def testRigidBodyNotInCollectBodies(): Unit \ Assert =
    let body = rigidBody2D("Projectile", mkPos(100.0f32, 100.0f32),
        {velocity = {x = 100.0f32, y = -200.0f32}, stuck = false},
        collisionShape2D("Collider", SceneTree.CollisionShapeData.CircleShape(12.5f32)) :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), body :: Nil);
    let bodies = SceneTree.collectBodies(root);
    Assert.assertEq(expected = 0, List.length(bodies));
    let rigids = SceneTree.collectRigidBodies(root);
    Assert.assertEq(expected = 1, List.length(rigids))

// --- StaticBody2D (Fixed) ---
// 動かないボディ。位置は固定。
// destroyed=true で描画・衝突判定ともに完全スキップ（存在しないのと同じ）。
// isSolid フラグが collectBodies の結果にそのまま反映される。

// isSolid=true/false がそれぞれ collectBodies の結果に正しく伝わる
@Test
def testStaticBodyIsSolidPropagation(): Unit \ Assert =
    let solidWall = staticBody2D("Wall", mkPos(0.0f32, 0.0f32),
        {isSolid = true, destroyed = false},
        collisionShape2D("WC", SceneTree.CollisionShapeData.RectShape({x = 80.0f32, y = 20.0f32})) :: Nil
    );
    let fragileBox = staticBody2D("Box", mkPos(100.0f32, 0.0f32),
        {isSolid = false, destroyed = false},
        collisionShape2D("BC", SceneTree.CollisionShapeData.RectShape({x = 80.0f32, y = 20.0f32})) :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), solidWall :: fragileBox :: Nil);
    let bodies = SceneTree.collectBodies(root);
    Assert.assertEq(expected = 2, List.length(bodies));
    let solidFlag = List.find(b -> b#name == "Wall", bodies) |> Option.map(b -> b#isSolid);
    let fragileFlag = List.find(b -> b#name == "Box", bodies) |> Option.map(b -> b#isSolid);
    Assert.assertEq(expected = Some(true), solidFlag);
    Assert.assertEq(expected = Some(false), fragileFlag)

// StaticBody2D は物理ステップ後も位置が変わらない
@Test
def testStaticBodyDoesNotMove(): Unit \ Assert =
    let body = staticBody2D("Wall", mkPos(200.0f32, 100.0f32),
        {isSolid = true, destroyed = false},
        collisionShape2D("WC", SceneTree.CollisionShapeData.RectShape({x = 80.0f32, y = 20.0f32})) :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), body :: Nil);
    let config = {screenSize = {x = 800.0f32, y = 600.0f32}, anchorPos = Vec2D.zero(), anchorWidth = 100.0f32};
    let newRoot = run {
        SceneTree.stepAndCollide(root, 1.0f32, config)
    } with handler SceneTree.OnCollision {
        def bodyEntered(_, _, _, k) = k(())
        def areaEntered(_, _, _, k) = k(())
    };
    let pos = SceneTree.globalPosition("Wall", newRoot);
    let px = pos |> Option.map(p -> p#x);
    let py = pos |> Option.map(p -> p#y);
    Assert.assertEq(expected = Some(200.0f32), px);
    Assert.assertEq(expected = Some(100.0f32), py)

// --- Area2D (Area) ---
// 描画されない検知エリア。物理的な実体を持たないセンサー。
// collectBodies に含まれるが、isSolid は常に false。
// 衝突時には bodyEntered ではなく areaEntered シグナルが発火する。

// collectBodies に含まれ、isSolid は必ず false になる
@Test
def testArea2DCollectedAsBodyNotSolid(): Unit \ Assert =
    let sensor = area2D("Sensor", mkPos(0.0f32, 590.0f32),
        {velocity = Vec2D.zero()},
        collisionShape2D("SensorCollider", SceneTree.CollisionShapeData.RectShape({x = 800.0f32, y = 10.0f32})) :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), sensor :: Nil);
    let bodies = SceneTree.collectBodies(root);
    Assert.assertEq(expected = 1, List.length(bodies));
    let solid = List.head(bodies) |> Option.map(b -> b#isSolid);
    Assert.assertEq(expected = Some(false), solid)

// Area2D との衝突イベントは targetKind が NodeKind.Area になる（= areaEntered の発火条件）
@Test
def testArea2DCollisionEventHasAreaKind(): Unit \ Assert =
    let projectile = rigidBody2D("Projectile", mkPos(112.5f32, 83.0f32),
        {velocity = {x = 0.0f32, y = 100.0f32}, stuck = false},
        collisionShape2D("ProjCollider", SceneTree.CollisionShapeData.CircleShape(12.5f32)) :: Nil
    );
    let sensor = area2D("Sensor", mkPos(100.0f32, 100.0f32),
        {velocity = Vec2D.zero()},
        collisionShape2D("SensorCollider", SceneTree.CollisionShapeData.RectShape({x = 50.0f32, y = 20.0f32})) :: Nil
    );
    let root = node2D("Root", Vec2D.zero(), projectile :: sensor :: Nil);
    let events = SceneTree.detectCollisions(root);
    Assert.assertEq(expected = 1, List.length(events));
    let isArea = List.head(events) |> Option.map(e ->
        match e#targetKind {
            case SceneTree.NodeKind.Area(_) => true
            case _ => false
        }
    );
    Assert.assertEq(expected = Some(true), isArea)

// --- checkShapeOverlap ---

@Test
def testCheckShapeOverlapRectRectHit(): Unit \ Assert =
    let result = SceneTree.checkShapeOverlap(
        {x = 0.0f32, y = 0.0f32}, SceneTree.CollisionShapeData.RectShape({x = 50.0f32, y = 50.0f32}),
        {x = 25.0f32, y = 25.0f32}, SceneTree.CollisionShapeData.RectShape({x = 50.0f32, y = 50.0f32}));
    Assert.assertTrue(result)

@Test
def testCheckShapeOverlapRectRectMiss(): Unit \ Assert =
    let result = SceneTree.checkShapeOverlap(
        {x = 0.0f32, y = 0.0f32}, SceneTree.CollisionShapeData.RectShape({x = 50.0f32, y = 50.0f32}),
        {x = 100.0f32, y = 100.0f32}, SceneTree.CollisionShapeData.RectShape({x = 50.0f32, y = 50.0f32}));
    Assert.assertFalse(result)

@Test
def testCheckShapeOverlapCircleRectHit(): Unit \ Assert =
    let result = SceneTree.checkShapeOverlap(
        {x = 112.5f32, y = 83.0f32}, SceneTree.CollisionShapeData.CircleShape(12.5f32),
        {x = 100.0f32, y = 100.0f32}, SceneTree.CollisionShapeData.RectShape({x = 50.0f32, y = 20.0f32}));
    Assert.assertTrue(result)

@Test
def testCheckShapeOverlapCircleRectMiss(): Unit \ Assert =
    let result = SceneTree.checkShapeOverlap(
        {x = 0.0f32, y = 0.0f32}, SceneTree.CollisionShapeData.CircleShape(12.5f32),
        {x = 100.0f32, y = 100.0f32}, SceneTree.CollisionShapeData.RectShape({x = 50.0f32, y = 20.0f32}));
    Assert.assertFalse(result)

@Test
def testCheckShapeOverlapRectCircleHit(): Unit \ Assert =
    let result = SceneTree.checkShapeOverlap(
        {x = 100.0f32, y = 100.0f32}, SceneTree.CollisionShapeData.RectShape({x = 50.0f32, y = 20.0f32}),
        {x = 112.5f32, y = 83.0f32}, SceneTree.CollisionShapeData.CircleShape(12.5f32));
    Assert.assertTrue(result)

@Test
def testCheckShapeOverlapCircleCircleHit(): Unit \ Assert =
    let result = SceneTree.checkShapeOverlap(
        {x = 0.0f32, y = 0.0f32}, SceneTree.CollisionShapeData.CircleShape(20.0f32),
        {x = 30.0f32, y = 0.0f32}, SceneTree.CollisionShapeData.CircleShape(20.0f32));
    Assert.assertTrue(result)

@Test
def testCheckShapeOverlapCircleCircleMiss(): Unit \ Assert =
    let result = SceneTree.checkShapeOverlap(
        {x = 0.0f32, y = 0.0f32}, SceneTree.CollisionShapeData.CircleShape(10.0f32),
        {x = 100.0f32, y = 0.0f32}, SceneTree.CollisionShapeData.CircleShape(10.0f32));
    Assert.assertFalse(result)
