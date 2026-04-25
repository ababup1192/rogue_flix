# SceneTree.flix 変更差分

パワーアップをシーンツリーに統合するために行った変更。

---

## 1. `AreaData` 型を追加し、`Area` がデータを持つように

```flix
// 追加
pub type alias AreaData = { velocity = Vec2D.Vec2 }

// 変更: Area → Area(AreaData)
case Area(AreaData)
```

**変更前**: `Area` はデータを持たない空のバリアントだった。DeathZone のような静止センサー専用。

**変更後**: `Area(AreaData)` で速度フィールドを持つ。これにより Area ノードが自律移動できるようになった。

**使われ方**:
- `BreakoutScene.buildInitialScene` — DeathZone を `{velocity = Vec2D.zero()}` で構築（静止エリア）
- `BreakoutScene.buildPowerUpNode` — パワーアップを `{velocity = {0, 150}}` で構築（落下する）

**パターンマッチ更新（3箇所）**: `Area` → `Area(_)` に変更。
- `collectBodiesWithGroup` — ボディ収集時
- `resolveDetectedCollisions` — Area との衝突は物理解決をスキップする判定
- `fireCollisionSignal` — Area なら `areaEntered`、それ以外は `bodyEntered` を発火する分岐

---

## 2. `area2D` コンストラクタが `AreaData` を受け取るように

```flix
// 変更前
pub def area2D(name: String, pos: Vec2D.Vec2, children: List[Node]): Node

// 変更後
pub def area2D(name: String, pos: Vec2D.Vec2, ad: AreaData, children: List[Node]): Node
```

**使われ方**: 上記の `buildInitialScene`（DeathZone）と `buildPowerUpNode`（PowerUp）。
テストファイル（TestScene.flix）でも `area2D` 呼び出し箇所に `{velocity = Vec2D.zero()}` を追加。

---

## 3. ツリー操作関数を追加

### `appendChildren`

```flix
pub def appendChildren(node: Node, extra: List[Node]): Node
```

ノードの子リスト末尾に `extra` を追加して返す。

**使われ方**: `BreakoutScene.addPowerUpToScene` — ブリック破壊時にスポーンしたパワーアップノードを PowerUps グループに追加する。

### `removeChild`

```flix
pub def removeChild(parentName: String, childName: String, root: Node): Node
```

指定した親ノードから `childName` の子を除去する。

**使われ方**: `BreakoutScene.removePowerUpFromScene` — 以下の3場面で呼ばれる。
- パドルがパワーアップに触れて収集したとき（`Game.onPaddleAreaEntered`）
- パワーアップが画面下端を超えたとき（`Game.removeOffScreenPowerUps`）
- ボールがデスゾーンに落ちて全パワーアップをリセットするとき（`Game.onBallAreaEntered`）

---

## 4. Sprite / Shape 更新ユーティリティを追加

### `updateChildSprite`

```flix
pub def updateChildSprite(parentName: String, f: SpriteData -> SpriteData, root: Node): Node
```

指定ノードの最初の Sprite 子ノードに `f` を適用する。

**使われ方**: `BreakoutScene.setPaddleSpriteColor` / `setBallSpriteColor` — パワーアップ発動中の色変更（Sticky=マゼンタ、PassThrough=赤など）。

### `updateChildSpriteAndShape`

```flix
pub def updateChildSpriteAndShape(parentName: String,
    fSprite: SpriteData -> SpriteData,
    fShape: CollisionShapeData -> CollisionShapeData, root: Node): Node
```

Sprite と CollisionShape の両方を一度に更新する。

**使われ方**: `BreakoutScene.increasePaddleWidth` / `resetPaddleWidth` — PadSizeIncrease パワーアップでパドルの見た目と当たり判定を同時に拡大・リセットする。

---

## 5. Rect-Rect（AABB）衝突判定を追加

### `checkRectRect`

```flix
pub def checkRectRect(posA: Vec2D.Vec2, sizeA: Vec2D.Vec2,
    posB: Vec2D.Vec2, sizeB: Vec2D.Vec2): Bool
```

2つの矩形が重なっているかを判定する。円×矩形の `checkCircleRect` とは別に、矩形同士の AABB 判定。

**使われ方**: `detectKinematicAreaOverlaps` 内で、パドル（Kinematic、矩形）とパワーアップ（Area、矩形）の重なりを検出する。

### `detectKinematicAreaOverlaps`

```flix
pub def detectKinematicAreaOverlaps(root: Node): List[CollisionEvent]
```

全 Kinematic ノードと全 Area ノードの矩形重なりを総当たりで検出し、`CollisionEvent` のリストを返す。

**使われ方**: `stepAndCollideFiltered` から呼ばれる。返された `CollisionEvent` は `fireCollisionSignal` で `areaEntered` シグナルとして発火され、`Game.applyCollisions` のハンドラで処理される。物理解決（位置補正・速度反転）はスキップする（パワーアップはトリガーゾーンなので）。

---

## 6. `physicsStepNode` に Area ケースを追加

```flix
case NodeKind.Area(ad) =>
    let newPos = {x = pos#x + ad#velocity#x * dt, y = pos#y + ad#velocity#y * dt};
    Node.MkNode(name, newPos, kind, children)
```

**変更前**: Area ノードは `case _ => node` に落ちて何もしなかった。

**変更後**: `velocity * dt` で毎フレーム移動する。画面端クランプなし（パワーアップは画面外に出てから `removeOffScreenPowerUps` で除去される）。

**使われ方**: パワーアップの落下アニメーション。`velocity = {x=0, y=150}` で毎フレーム下に移動する。

---

## 7. `stepAndCollide` / `stepAndCollideFiltered` の拡張

```flix
// 変更前: stepAndCollide が直接実装
pub def stepAndCollide(...): Node \ OnCollision =
    let movedRoot = physicsStepNode(node, dt, config);
    let events = detectCollisions(movedRoot);
    List.forEach(fireCollisionSignal, events);
    resolveDetectedCollisions(movedRoot, events)

// 変更後: stepAndCollideFiltered に委譲 + Area 衝突判定を統合
pub def stepAndCollide(...) = stepAndCollideFiltered(..., _ -> true)

pub def stepAndCollideFiltered(..., shouldResolve): Node \ OnCollision =
    let movedRoot = physicsStepNode(node, dt, config);
    let rigidEvents = detectCollisions(movedRoot);
    let areaOverlapEvents = detectKinematicAreaOverlaps(movedRoot);  // ← 新規
    let allEvents = List.append(rigidEvents, areaOverlapEvents);
    List.forEach(fireCollisionSignal, allEvents);
    let resolveEvents = List.filter(shouldResolve, rigidEvents);     // ← フィルタ追加
    resolveDetectedCollisions(movedRoot, resolveEvents)
```

**変更点**:
1. `detectKinematicAreaOverlaps` を追加呼び出しし、パドル×パワーアップの衝突を検出
2. `shouldResolve` フィルタにより、PassThrough パワーアップ発動中に非 Solid ブリックとの物理解決をスキップできるようになった

**使われ方**: `BreakoutScene.stepAndCollide` が `shouldResolve` を渡す。PassThrough 発動中は非 Solid ブリックを通過する（衝突シグナルは発火するがボールは跳ね返らない）。
