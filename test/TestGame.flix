// Tests for Game.updateGame — 入力処理 (processInput) と物理ステップ (stepPhysics) の統合テスト
//
// updateGame は以下の2段パイプラインで構成される:
//   1. processInput: キー入力を読み、プレイヤーの移動命令を発行
//   2. stepPhysics:  CharacterBody2D を targetPos に向けて補間移動
//
// Game エフェクトをハンドラでモック化し、キー入力とデルタタイムを制御する。

// ========================================================================
// ヘルパー: テスト用シーンと Game エフェクトハンドラ
// ========================================================================

/// テスト用の初期シーンを構築する。
/// row, col でプレイヤーのグリッド位置を指定。
def mkTestState(row: Int32, col: Int32): Game.GameState =
    {scene = RogueScene.buildInitialScene(
        Game.gridCols(), Game.gridRows(), col, row,
        Game.tileSize(), Game.moveSpeed()
    )}

/// 1フレーム分の updateGame を実行するヘルパー。
/// pressedKeys: 押下中のキーコードのリスト（Nil なら全キー未押下）
/// dt: フレームのデルタタイム
def runOneFrameMultiKey(state: Game.GameState, pressedKeys: List[Int32], dt: Float32): Game.GameState =
    run {
        Game.updateGame(state)
    } with handler Game.Game {
        def getInitialState(k)       = k(state)
        def render(_scene, k)        = k(())
        def shouldClose(k)           = k(true)
        def getDeltaTime(k)          = k(dt)
        def isKeyPressed(keyCode, k) = k(List.exists(key -> keyCode == key, pressedKeys))
    }

/// 複数フレームを連続実行するヘルパー。
/// keyPerFrame: フレームごとに押すキーのリスト（各要素が1フレームの押下キーに対応）
/// dt: 各フレームのデルタタイム
def runFrames(state: Game.GameState, keyPerFrame: List[Int32], dt: Float32): Game.GameState =
    List.foldLeft((s, key) -> runOneFrameMultiKey(s, key :: Nil, dt), state, keyPerFrame)


// ========================================================================
// A1. キーマッピング (基本方向)
// ========================================================================

// --- キー未押下: プレイヤー状態不変 ---
// どのキーも押されていないとき、プレイヤーの targetPos が変化しないことを確認。
// ※ キー無し1フレームは runOneFrameMultiKey を直接使用
@Test
def testUpdateGameNoInput(): Unit \ Assert =
    let state = mkTestState(4, 4);
    let result = runOneFrameMultiKey(state, Nil, 0.0f32);
    let gp = PlayerScene.getPlayerTargetGrid(result#scene, Game.tileSize());
    Assert.assertEq(expected = (4, 4), (gp#row, gp#col))

// --- Wキー: 上方向に移動命令 ---
// Wキー押下で targetPos が1タイル上にセットされることを確認。
// keyW(87) が Direction.Up にマッピングされる検証。
@Test
def testUpdateGameKeyW(): Unit \ Assert =
    let state = mkTestState(4, 4);
    let result = runFrames(state, Game.keyW() :: Nil, 0.0f32);
    let gp = PlayerScene.getPlayerTargetGrid(result#scene, Game.tileSize());
    Assert.assertEq(expected = (3, 4), (gp#row, gp#col))

// --- Sキー: 下方向に移動命令 ---
// Sキー押下で targetPos が1タイル下にセットされることを確認。
// keyS(83) が Direction.Down にマッピングされる検証。
@Test
def testUpdateGameKeyS(): Unit \ Assert =
    let state = mkTestState(4, 4);
    let result = runFrames(state, Game.keyS() :: Nil, 0.0f32);
    let gp = PlayerScene.getPlayerTargetGrid(result#scene, Game.tileSize());
    Assert.assertEq(expected = (5, 4), (gp#row, gp#col))

// --- Aキー: 左方向に移動命令 ---
// Aキー押下で targetPos が1タイル左にセットされることを確認。
// keyA(65) が Direction.Left にマッピングされる検証。
@Test
def testUpdateGameKeyA(): Unit \ Assert =
    let state = mkTestState(4, 4);
    let result = runFrames(state, Game.keyA() :: Nil, 0.0f32);
    let gp = PlayerScene.getPlayerTargetGrid(result#scene, Game.tileSize());
    Assert.assertEq(expected = (4, 3), (gp#row, gp#col))

// --- Dキー: 右方向に移動命令 ---
// Dキー押下で targetPos が1タイル右にセットされることを確認。
// keyD(68) が Direction.Right にマッピングされる検証。
@Test
def testUpdateGameKeyD(): Unit \ Assert =
    let state = mkTestState(4, 4);
    let result = runFrames(state, Game.keyD() :: Nil, 0.0f32);
    let gp = PlayerScene.getPlayerTargetGrid(result#scene, Game.tileSize());
    Assert.assertEq(expected = (4, 5), (gp#row, gp#col))

// --- 矢印↑キー: Wキーと同等の動作 ---
// 矢印↑キーでもWキーと同じ上方向移動が発生することを確認。
// processInput の `or` による代替キーバインドの検証。
@Test
def testUpdateGameArrowUp(): Unit \ Assert =
    let state = mkTestState(4, 4);
    let result = runFrames(state, Game.keyUp() :: Nil, 0.0f32);
    let gp = PlayerScene.getPlayerTargetGrid(result#scene, Game.tileSize());
    Assert.assertEq(expected = (3, 4), (gp#row, gp#col))

// ========================================================================
// A2. 入力ガード (優先度・移動中の無視)
// ========================================================================

// --- W + D 同時押し: 上が優先される ---
// if-else チェイン (up, down, left, right の順) により、
// W(上) と D(右) を同時押ししても上方向のみ反映される。
// ※ 同時押しテストのみ runOneFrameMultiKey を直接使用
@Test
def testUpdateGameKeyPriority(): Unit \ Assert =
    let state = mkTestState(4, 4);
    let result = runOneFrameMultiKey(state, Game.keyW() :: Game.keyD() :: Nil, 0.0f32);
    let gp = PlayerScene.getPlayerTargetGrid(result#scene, Game.tileSize());
    Assert.assertEq(expected = (3, 4), (gp#row, gp#col))

// --- 移動中はキー入力を無視 ---
// targetPos を隣のグリッドにセットして移動中にした状態でWキーを押す。
// isPlayerMoving ガードにより targetPos は変わらない。
@Test
def testUpdateGameIgnoresInputWhileMoving(): Unit \ Assert =
    let state = mkTestState(4, 4);
    let movingState = {scene = PlayerScene.setPlayerTargetGrid({row = 4, col = 5}, Game.tileSize(), state#scene)};
    let result = runFrames(movingState, Game.keyW() :: Nil, 0.0f32);
    let gp = PlayerScene.getPlayerTargetGrid(result#scene, Game.tileSize());
    Assert.assertEq(expected = (4, 5), (gp#row, gp#col))

// --- 複数歩移動: Wキー3回で3タイル上に到達 ---
// 1フレームで移動完了する dt(0.2s) を使い、3フレーム連続でWキーを押す。
// moveSpeed(192) × dt(0.2) = 38.4 > tileSize(32) なので1フレームで1タイル完走。
// 開始 row=5 → 1歩 row=4 → 2歩 row=3 → 3歩 row=2（全て Room1 床タイル内）
@Test
def testUpdateGameMultipleSteps(): Unit \ Assert =
    let dt = 0.2f32;
    let s0 = mkTestState(5, 4);
    let result = runFrames(s0, Game.keyW() :: Game.keyW() :: Game.keyW() :: Nil, dt);
    let gp = PlayerScene.getPlayerTargetGrid(result#scene, Game.tileSize());
    let pos = PlayerScene.getPlayerPosition(result#scene);
    let expected = Grid.toWorld({row = 2, col = 4}, Game.tileSize());
    Assert.assertEq(expected = (2, 4), (gp#row, gp#col));
    Assert.assertEq(expected = (expected#x, expected#y), (pos#x, pos#y))

// ========================================================================
// A3. 壁衝突 (レイキャストによる移動制限)
// ========================================================================

// --- Wキー: 上方向に壁があり移動できない ---
// プレイヤーが Room1 の上端 (row=2, col=4) にいるとき、
// Wキーで上方向に移動しようとしても、壁 (row=1, col=4) に阻まれて位置が変わらない。
@Test
def testUpdateGameBlockedByWallUp(): Unit \ Assert =
    let state = mkTestState(2, 4);
    let result = runFrames(state, Game.keyW() :: Nil, 0.0f32);
    let gp = PlayerScene.getPlayerTargetGrid(result#scene, Game.tileSize());
    Assert.assertEq(expected = (2, 4), (gp#row, gp#col))

// ========================================================================
// B. 物理ステップ統合テスト (processInput + stepPhysics)
// ========================================================================

// --- dt > 0 で移動中のプレイヤーが targetPos に向かって補間される ---
// targetPos を1タイル上 (128, 96) にセットした状態で dt=0.1 を与える。
// moveSpeed(192) × dt(0.1) = 19.2 だけ targetPos 方向に移動する。
// ※ キー無し1フレームは runOneFrameMultiKey を直接使用
@Test
def testUpdateGamePhysicsInterpolation(): Unit \ Assert =
    let state = mkTestState(4, 4);
    let movingState = {scene = PlayerScene.setPlayerTarget({x = 128.0f32, y = 96.0f32}, state#scene)};
    let result = runOneFrameMultiKey(movingState, Nil, 0.1f32);
    let after = PlayerScene.getPlayerPosition(result#scene);
    Assert.assertEq(expected = (128.0f32, 108.8f32), (after#x, after#y))
