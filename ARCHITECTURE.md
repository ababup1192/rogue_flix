# Breakout Flix - プログラム解説ドキュメント

Flix 言語と LWJGL (OpenGL 3.3 Core Profile) で実装された、
LearnOpenGL チュートリアル準拠の Breakout ゲームの動作原理を解説する。

---

## 目次

1. [概要](#1-概要)
2. [プロジェクト構成](#2-プロジェクト構成)
3. [プログラム起動〜終了の全体フロー](#3-プログラム起動終了の全体フロー)
4. [データ構造](#4-データ構造)
5. [レベルファイルの読み込みと解析](#5-レベルファイルの読み込みと解析)
6. [テクスチャの読み込み（STBImage）](#6-テクスチャの読み込みstbimage)
7. [シェーダの原理と詳細解説](#7-シェーダの原理と詳細解説)
8. [座標系と行列変換](#8-座標系と行列変換)
9. [スプライトレンダリングの仕組み](#9-スプライトレンダリングの仕組み)
10. [ゲームループの構造](#10-ゲームループの構造)
11. [レンダリング1フレームの描画順序](#11-レンダリング1フレームの描画順序)
12. [Flix言語の特徴的な使い方](#12-flix言語の特徴的な使い方)
13. [技術スタック図](#13-技術スタック図)

---

## 1. 概要

本プロジェクトは、[LearnOpenGL - Breakout](https://learnopengl.com/In-Practice/2D-Game/Breakout)
チュートリアルを Flix 言語で再現したものである。

- **言語**: Flix 0.71.0（JVM 上で動作する関数型プログラミング言語）
- **グラフィックス**: OpenGL 3.3 Core Profile
- **ウィンドウ管理**: GLFW 3.3.4（LWJGL 経由）
- **画像読み込み**: STBImage（LWJGL 経由）
- **ビルドシステム**: Flix 組み込みビルダー + Maven 依存解決

ゲーム画面は 800×600 ピクセルで、背景・ブリック（壊せるブロック）・
パドル・ボールをテクスチャ付きスプライトとして描画する。

---

## 2. プロジェクト構成

```
breakout_flix/
├── src/
│   └── Main.flix          # ゲーム本体（566行、全ロジックを含む）
├── test/
│   └── TestMain.flix      # テスト（35行）
├── levels/                # LearnOpenGL 準拠のレベルデータ
│   ├── one.lvl            # Level 1: 虹色グラデーション
│   ├── two.lvl            # Level 2: ストライプパターン
│   ├── three.lvl          # Level 3: スペースインベーダー風
│   └── four.lvl           # Level 4: ダイヤモンドパターン
├── textures/              # スプライト用テクスチャ画像
│   ├── background.jpg     # 背景画像（RGB）
│   ├── block.png          # 通常ブロック（RGBA）
│   ├── block_solid.png    # 壊れないブロック（RGBA）
│   ├── paddle.png         # パドル（RGBA）
│   └── awesomeface.png    # ボール（RGBA）
├── lib/                   # ネイティブライブラリ & 外部 JAR
│   ├── cache/             # Maven からダウンロードされた LWJGL JAR
│   └── external/          # Java ラッパー JAR
├── bin/
│   └── flix.jar           # Flix コンパイラ v0.71.0
├── run.sh                 # macOS 対応起動スクリプト
├── flix.toml              # プロジェクト設定 & 依存関係
├── CLAUDE.md              # 開発ガイド
└── README.md
```

---

## 3. プログラム起動〜終了の全体フロー

`main()` 関数（`src/Main.flix:494`）が全体のエントリーポイントである。

```
┌─────────────────────────────────────────────────┐
│                    main()                       │
└───────────────────────┬─────────────────────────┘
                        │
                        ▼
              ┌─────────────────┐
              │  GLFW 初期化     │  glfwInit()
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │  ウィンドウ作成  │  glfwCreateWindow(800, 600)
              │  OpenGL 3.3     │  glfwWindowHint(...)
              │  Core Profile   │
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │  OpenGL 初期化   │  GL.createCapabilities()
              │  ビューポート設定 │  glViewport(0, 0, 1600, 1200)
              │  ブレンド有効化   │  glEnable(GL_BLEND)
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │  シェーダ構築     │  createShaderProgram()
              │  射影行列セット   │  setProjectionMatrix()
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │  VAO/VBO 初期化  │  initSpriteRenderer()
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │  テクスチャ読込   │  loadTextures()
              │  (5種類)         │  STBImage 経由
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │  ゲーム状態初期化 │  initGame()
              │  (4レベル読込)    │  loadLevel() × 4
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │  ゲームループ     │  gameLoop() ← 末尾再帰
              │  (ESC で脱出)    │
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │  リソース解放     │  glfwFreeCallbacks()
              │  GLFW 終了       │  glfwTerminate()
              └─────────────────┘
```

### macOS 固有の注意点

`run.sh` では macOS 上で `-XstartOnFirstThread` フラグを付けて JVM を起動する。
GLFW は macOS のメインスレッドで動作する必要があるため、このフラグが必須となる。

また、Retina ディスプレイ対応として `retinaScale = 2` を設定し、
実際のフレームバッファサイズは 1600×1200 ピクセルとなる（`src/Main.flix:515-520`）。

---

## 4. データ構造

すべての型は `src/Main.flix:36-58` で定義されている。
Flix のレコード型（`type alias`）を使い、不変データ構造として表現される。

### 型定義一覧

```flix
type alias Vec2 = {x = Float32, y = Float32}
type alias Vec3 = {r = Float32, g = Float32, b = Float32}

type alias GameObject = {
    position = Vec2, size = Vec2, color = Vec3,
    isSolid = Bool, destroyed = Bool, textureId = Int32
}

type alias GameLevel  = { bricks = List[GameObject] }

type alias GameState  = {
    levels = List[GameLevel], currentLevel = Int32,
    player = GameObject, ballPos = Vec2, ballRadius = Float32
}

type alias Textures   = {
    background = Int32, block = Int32, blockSolid = Int32,
    paddle = Int32, ball = Int32
}
```

### メモリ上のデータ構造

```
GameState
├── levels: List[GameLevel]
│   ├── [0] GameLevel (one.lvl)
│   │   └── bricks: List[GameObject]
│   │       ├── GameObject { pos=(0,0), size=(53.3,37.5), color=Orange, ... }
│   │       ├── GameObject { pos=(53.3,0), size=(53.3,37.5), color=Orange, ... }
│   │       └── ... (106個のブリック)
│   ├── [1] GameLevel (two.lvl)
│   ├── [2] GameLevel (three.lvl)
│   └── [3] GameLevel (four.lvl)
│
├── currentLevel: 0
│
├── player: GameObject
│   ├── position: {x=350.0, y=580.0}     ← 画面下部中央
│   ├── size:     {x=100.0, y=20.0}
│   ├── color:    {r=1.0, g=1.0, b=1.0}  ← 白（テクスチャそのまま）
│   ├── isSolid:  true
│   ├── destroyed: false
│   └── textureId: (paddle テクスチャID)
│
├── ballPos: {x=387.5, y=555.0}           ← パドル直上
└── ballRadius: 12.5
```

**パドル初期位置の計算**（`src/Main.flix:418-419`）:
- `playerX = 800 / 2 - 100 / 2 = 350.0`
- `playerY = 600 - 20 = 580.0`

**ボール初期位置の計算**（`src/Main.flix:430-431`）:
- `ballX = 350.0 + 100 / 2 - 12.5 = 387.5`
- `ballY = 580.0 - 12.5 * 2 = 555.0`

---

## 5. レベルファイルの読み込みと解析

### .lvl ファイルフォーマット

レベルファイルはスペース区切りの整数行列で、各整数がタイルタイプを表す。

```
タイル値  意味              色                     テクスチャ
──────────────────────────────────────────────────────────────
  0       空白（ブリックなし） -                      -
  1       壊れないブロック    (0.8, 0.8, 0.7) ベージュ  block_solid.png
  2       通常ブロック       (0.2, 0.6, 1.0) 青       block.png
  3       通常ブロック       (0.0, 0.7, 0.0) 緑       block.png
  4       通常ブロック       (0.8, 0.8, 0.4) 黄       block.png
  5       通常ブロック       (1.0, 0.5, 0.0) オレンジ   block.png
```

色の対応は `tileColor()`（`src/Main.flix:392-400`）で定義されている。
タイプ 1 のブロックだけ `block_solid.png` が使われ、`isSolid = true` となる。

### パース処理の流れ

```
loadLevel(path)                          [src/Main.flix:298]
  │
  ├── ファイル読み込み: Fs.FileRead.read(path)
  │
  └── parseLevel(data, width, height)    [src/Main.flix:312]
        │
        ├── 1. 文字列を "\n" で分割 → 行リスト
        │
        ├── 2. 各行を parseLevelLine() でパース
        │      "5 5 5 5 5" → [5, 5, 5, 5, 5]: List[Int32]
        │
        ├── 3. 空行を除去 → validRows
        │
        ├── 4. ブリックサイズ計算:
        │      unitWidth  = levelWidth  / 列数
        │      unitHeight = levelHeight / 行数
        │
        └── 5. buildBricks(rows, ...)    [src/Main.flix:349]
              │
              └── 各行について buildBrickRow()  [src/Main.flix:367]
                    │
                    ├── tileType == 0 → スキップ
                    ├── tileType == 1 → solid ブロック生成
                    └── tileType >= 2 → 通常ブロック生成
```

### Level 1 (one.lvl) のブリック配置

レベル描画領域は画面上半分（800×300 ピクセル）。
15列 × 8行なので、各ブリックは約 53.3×37.5 ピクセル。

```
          Level 1: one.lvl (15列 × 8行)
  0       200       400       600       800
  ├─────────┼─────────┼─────────┼─────────┤
  │ O O O O O O O O O O O O O O O │  行0: オレンジ(5) × 15
  │ O O O O O O O O O O O O O O O │  行1: オレンジ(5) × 15
  │ Y Y Y Y Y · · · · · Y Y Y Y Y │  行2: 黄(4) × 10, 空(0) × 5
  │ Y S Y S Y · · S · · Y S Y S Y │  行3: 黄(4) + 壊れない(1)
  │ G G G G G · · · · · G G G G G │  行4: 緑(3) × 10, 空(0) × 5
  │ G G S G G G G G G G G G S G G │  行5: 緑(3) + 壊れない(1)
  │ B B B B B B B B B B B B B B B │  行6: 青(2) × 15
  │ B B B B B B B B B B B B B B B │  行7: 青(2) × 15
  ├─────────┼─────────┼─────────┼─────────┤

  凡例: O=オレンジ  Y=黄  G=緑  B=青  S=壊れない  ·=空
```

非ゼロタイルの合計は **106個**（テストで検証済み: `test/TestMain.flix:14-19`）。

---

## 6. テクスチャの読み込み（STBImage）

テクスチャの読み込みは `loadTexture()`（`src/Main.flix:150`）と
`loadTextures()`（`src/Main.flix:178`）で行われる。

### 読み込みフロー

```
loadTexture(path, alpha)
  │
  ├── 1. MemoryStack 確保
  │      width, height, channels 用のバッファを mallocInt(1)
  │
  ├── 2. STBImage 設定
  │      stbi_set_flip_vertically_on_load(true)
  │      ↑ OpenGL は左下原点、画像は左上原点なので Y 軸反転
  │
  ├── 3. 画像読み込み
  │      stbi_load(path, w, h, c, channels)
  │      channels = 4 (RGBA) or 3 (RGB)
  │
  ├── 4. OpenGL テクスチャ生成
  │      glGenTextures() → テクスチャID
  │      glBindTexture(GL_TEXTURE_2D, id)
  │
  ├── 5. ピクセルデータ転送
  │      glTexImage2D(GL_TEXTURE_2D, 0, format, w, h, 0, format,
  │                   GL_UNSIGNED_BYTE, data)
  │
  ├── 6. テクスチャパラメータ設定
  │      WRAP_S, WRAP_T = GL_REPEAT      ← UV が 0-1 を超えた場合繰り返す
  │      MIN_FILTER     = GL_LINEAR      ← 縮小時: 線形補間
  │      MAG_FILTER     = GL_LINEAR      ← 拡大時: 線形補間
  │
  ├── 7. ピクセルデータ解放
  │      stbi_image_free(data)
  │
  └── 8. テクスチャID を返す
```

### RGB vs RGBA の使い分け

```
テクスチャファイル       alpha   フォーマット    理由
─────────────────────────────────────────────────────────────
background.jpg         false   GL_RGB        背景は不透明、JPEG は RGB のみ
block.png              true    GL_RGBA       ブロック形状の透過が必要
block_solid.png        true    GL_RGBA       同上
paddle.png             true    GL_RGBA       パドル形状の透過が必要
awesomeface.png        true    GL_RGBA       ボール（円形）の透過が必要
```

### テクスチャパラメータの意味

```
                           GL_LINEAR (線形補間)
                           ┌─────────────────────┐
  テクスチャ (64×64)        │  近隣4ピクセルの加重  │
  ┌────┐                   │  平均で滑らかに補間   │
  │████│  → 拡大 (200×200)  │                     │
  │████│     ▼              │  GL_NEAREST なら     │
  └────┘  ┌──────────┐     │  最近傍1ピクセルで    │
          │██████████│     │  ドット感が出る       │
          │██████████│     └─────────────────────┘
          │██████████│
          └──────────┘

  GL_REPEAT (ラッピング)
  ┌────┐ ┌────┐ ┌────┐
  │ AB │ │ AB │ │ AB │   UV 座標が 0-1 を超えると
  │ CD │ │ CD │ │ CD │   テクスチャが繰り返される
  └────┘ └────┘ └────┘   （本プログラムでは UV は 0-1 範囲内）
```

---

## 7. シェーダの原理と詳細解説

### GPU レンダリングパイプラインの全体像

シェーダとは GPU 上で実行される小さなプログラムである。
OpenGL 3.3 Core Profile では、頂点シェーダとフラグメントシェーダの
2つを必ず自分で記述する必要がある。

```
  CPU 側 (Flix / JVM)                GPU 側 (OpenGL)
 ┌──────────────────┐
 │  頂点データ準備    │
 │  (VAO/VBO)       │
 └────────┬─────────┘
          │ glDrawArrays(GL_TRIANGLES, 0, 6)
          ▼
 ═══════════════════════════════════════════════════════════
          │
          ▼
 ┌──────────────────┐   各頂点に対して 1回ずつ実行（計6回）
 │  頂点シェーダ      │   入力: vec4 vertex (x, y, u, v)
 │  (Vertex Shader)  │   出力: gl_Position (画面上の位置)
 │                   │         TexCoords (テクスチャ座標)
 └────────┬─────────┘
          │
          ▼
 ┌──────────────────┐   3頂点→三角形を構成
 │  プリミティブ組立   │   2つの三角形 → 四角形
 └────────┬─────────┘
          │
          ▼
 ┌──────────────────┐   三角形内部のピクセルを列挙
 │  ラスタライズ      │   頂点間の TexCoords を補間
 └────────┬─────────┘
          │
          ▼
 ┌──────────────────┐   各ピクセルに対して 1回ずつ実行
 │  フラグメント       │   入力: TexCoords (補間済み)
 │  シェーダ          │   処理: テクスチャサンプリング × 色
 │  (Fragment Shader)│   出力: color (RGBA)
 └────────┬─────────┘
          │
          ▼
 ┌──────────────────┐   アルファブレンディング等
 │  ブレンディング     │   既存ピクセルと合成
 └────────┬─────────┘
          │
          ▼
 ┌──────────────────┐
 │  フレームバッファ   │   最終的な画面ピクセル
 └──────────────────┘
```

### 頂点シェーダの仕組み

`src/Main.flix:64-73` で定義されている GLSL ソースコード:

```glsl
#version 330 core
layout (location = 0) in vec4 vertex;    // 入力: (x, y, u, v)
out vec2 TexCoords;                      // 出力: フラグメントシェーダへ渡す UV
uniform mat4 model;                      // スプライトの位置・サイズ
uniform mat4 projection;                 // 正射影行列

void main() {
    TexCoords = vertex.zw;               // z,w 成分がテクスチャ座標
    gl_Position = projection * model * vec4(vertex.xy, 0.0, 1.0);
}
```

**処理の流れ:**

```
  入力 vertex = (x, y, u, v)
  例: (0.0, 1.0, 0.0, 1.0) ← クワッドの左下頂点

  1. テクスチャ座標の抽出:
     TexCoords = (u, v) = (0.0, 1.0)

  2. 位置の変換:
     ローカル座標  →  model行列   →  ワールド座標  →  projection行列  →  クリップ座標
     (0.0, 1.0)       平行移動          (px, py+h)        正射影           NDC
                       +スケール
```

**座標変換の数式:**

```
  gl_Position = projection × model × vec4(x, y, 0, 1)

  具体例: 位置 (100, 200)、サイズ (50, 30) のスプライト
  頂点 (0, 0) の場合:

  model × (0, 0, 0, 1)^T = (100, 200, 0, 1)^T    ← 左上角
  model × (1, 0, 0, 1)^T = (150, 200, 0, 1)^T    ← 右上角
  model × (0, 1, 0, 1)^T = (100, 230, 0, 1)^T    ← 左下角
  model × (1, 1, 0, 1)^T = (150, 230, 0, 1)^T    ← 右下角
```

### フラグメントシェーダの仕組み

`src/Main.flix:75-83` で定義されている GLSL ソースコード:

```glsl
#version 330 core
in vec2 TexCoords;                       // 頂点シェーダから補間された UV
out vec4 color;                          // 出力: 最終ピクセル色
uniform sampler2D image;                 // テクスチャユニット
uniform vec3 spriteColor;                // 乗算色（カラーティンティング）

void main() {
    color = vec4(spriteColor, 1.0) * texture(image, TexCoords);
}
```

**カラーティンティングの仕組み:**

```
  テクスチャ色 × スプライト色 = 最終色

  例: 緑のブロック
  texture(image, UV) = (0.9, 0.9, 0.9, 0.8)   ← テクスチャの色（灰色半透明）
  spriteColor        = (0.0, 0.7, 0.0)         ← 緑
  vec4(spriteColor, 1.0) = (0.0, 0.7, 0.0, 1.0)

  最終色 = (0.0×0.9, 0.7×0.9, 0.0×0.9, 1.0×0.8)
         = (0.0,     0.63,    0.0,     0.8)     ← 緑がかった半透明

  ※ spriteColor = (1,1,1) なら色の変更なし（白 × 何色 = 何色）
    → 背景・パドル・ボールは白を指定してテクスチャ色そのまま使用
```

### シェーダコンパイル〜リンクの流れ

`createShaderProgram()`（`src/Main.flix:113`）で実行される。

```
  compileShader(vertexSrc, GL_VERTEX_SHADER)     [src/Main.flix:94]
  ├── glCreateShader(GL_VERTEX_SHADER)     → シェーダオブジェクト生成
  ├── glShaderSource(shader, source)        → ソースコード設定
  ├── glCompileShader(shader)               → GLSL コンパイル
  └── glGetShaderi(GL_COMPILE_STATUS)       → 成功確認（失敗なら bug!）
         ↓
  compileShader(fragmentSrc, GL_FRAGMENT_SHADER)  同様の手順
         ↓
  createShaderProgram()                      [src/Main.flix:113]
  ├── glCreateProgram()                     → プログラムオブジェクト生成
  ├── glAttachShader(program, vs)           → 頂点シェーダ接続
  ├── glAttachShader(program, fs)           → フラグメントシェーダ接続
  ├── glLinkProgram(program)                → 2つのシェーダをリンク
  ├── glGetProgrami(GL_LINK_STATUS)         → 成功確認
  ├── glDeleteShader(vs)                    → コンパイル済みシェーダ解放
  ├── glDeleteShader(fs)                    │  （プログラムにはコピー済み）
  └── return program                        → プログラムID を返す
```

---

## 8. 座標系と行列変換

### 正射影行列（Orthographic Projection）の原理

通常の 3D グラフィックスでは透視投影（遠近感あり）を使うが、
2D ゲームでは**正射影**（遠近感なし）を使う。

正射影行列は「ピクセル座標」を OpenGL の「正規化デバイス座標（NDC: -1〜+1）」に
変換する。

`setProjectionMatrix()`（`src/Main.flix:236`）で設定される。

```
  画面座標系 (0,0)〜(800,600)        NDC (-1,-1)〜(+1,+1)
  ┌──────────────────────┐          ┌──────────────────────┐
  │(0,0)          (800,0)│          │(-1,+1)      (+1,+1)  │
  │                      │   ───►   │                      │
  │                      │  正射影   │                      │
  │                      │   行列    │                      │
  │(0,600)      (800,600)│          │(-1,-1)      (+1,-1)  │
  └──────────────────────┘          └──────────────────────┘
    ↑ Y軸下向き（画面座標）              ↑ Y軸上向き（OpenGL 標準）
```

**座標の対応関係:**

| 画面座標 | NDC |
|---------|-----|
| (0, 0) = 左上 | (-1, +1) |
| (800, 0) = 右上 | (+1, +1) |
| (0, 600) = 左下 | (-1, -1) |
| (800, 600) = 右下 | (+1, -1) |

### 正射影行列の数式

パラメータ: `left=0, right=800, bottom=600, top=0`

`top=0, bottom=600` とすることで Y 軸が反転し、
画面座標系の「下向きが正」を実現している。

```
             ┌  2/(r-l)    0        0       -(r+l)/(r-l)  ┐
  Proj =     │  0        2/(t-b)    0       -(t+b)/(t-b)  │
             │  0          0       -1        0             │
             └  0          0        0        1             ┘

  実際の値 (l=0, r=800, t=0, b=600):

             ┌  2/800      0        0       -1     ┐     ┌  0.0025   0        0    -1  ┐
  Proj =     │  0        2/-600     0        1     │  =  │  0       -0.0033   0     1  │
             │  0          0       -1        0     │     │  0        0       -1     0  │
             └  0          0        0        1     ┘     └  0        0        0     1  ┘
```

**検算: 画面中央 (400, 300) を変換**

```
  Proj × (400, 300, 0, 1)^T
  = (0.0025×400 - 1, -0.0033×300 + 1, 0, 1)^T
  = (0, 0, 0, 1)^T    ← NDC の原点 = 画面中央 ✓
```

### モデル行列（Model Matrix）

各スプライトの位置とサイズを表す 4×4 行列。
`drawSprite()` 内で毎回構築される（`src/Main.flix:267-272`）。

```
  通常の Model 行列は 平行移動 × 回転 × スケーリング だが、
  本プログラムでは回転なし。平行移動とスケーリングを1つの行列にまとめている:

             ┌  sx    0     0     tx  ┐
  Model =    │  0     sy    0     ty  │
             │  0     0     1     0   │
             └  0     0     0     1   ┘

  sx, sy = スプライトの幅、高さ (size#x, size#y)
  tx, ty = スプライトの位置      (pos#x, pos#y)
```

**変換の例: パドル (position=(350,580), size=(100,20))**

```
             ┌  100   0     0     350 ┐     ┌ 0 ┐     ┌ 350 ┐
  Model ×    │  0     20    0     580 │  ×  │ 0 │  =  │ 580 │   ← 左上角
             │  0     0     1     0   │     │ 0 │     │ 0   │
             └  0     0     0     1   ┘     └ 1 ┘     └ 1   ┘

             ┌  100   0     0     350 ┐     ┌ 1 ┐     ┌ 450 ┐
  Model ×    │  0     20    0     580 │  ×  │ 1 │  =  │ 600 │   ← 右下角
             │  0     0     1     0   │     │ 0 │     │ 0   │
             └  0     0     0     1   ┘     └ 1 ┘     └ 1   ┘
```

### 行列の掛け算の順序

```
  gl_Position = Projection × Model × vertex
                │             │        │
                │             │        └── ローカル座標 (0〜1 の正規化クワッド)
                │             └─────────── ワールド座標へ変換 (ピクセル単位)
                └───────────────────────── NDC へ変換 (-1〜+1)
```

行列の掛け算は右から左に適用される。まず Model でスケーリング+平行移動し、
次に Projection で NDC に変換する。

---

## 9. スプライトレンダリングの仕組み

### VAO/VBO の構造

`initSpriteRenderer()`（`src/Main.flix:206`）で生成される。
すべてのスプライトで**同じクワッド**を使い回す。
位置・サイズの違いは Model 行列で吸収する。

#### 頂点データ（6頂点 × 4成分 = 24 float）

```
  頂点番号   x     y     u     v      位置
  ────────────────────────────────────────────
  v0        0.0   1.0   0.0   1.0    左下
  v1        1.0   0.0   1.0   0.0    右上
  v2        0.0   0.0   0.0   0.0    左上
  v3        0.0   1.0   0.0   1.0    左下
  v4        1.0   1.0   1.0   1.0    右下
  v5        1.0   0.0   1.0   0.0    右上
```

#### 三角形分割

```
  (0,0)                   (1,0)
  左上 v2─────────────────右上 v1,v5
       │ ╲                │
       │   ╲  三角形1     │
       │     ╲  (v2,v1,v0)│
       │       ╲          │
       │         ╲        │
       │           ╲      │
       │  三角形2    ╲    │
       │  (v3,v4,v5)   ╲  │
       │                 ╲│
  左下 v0,v3──────────────右下 v4
  (0,1)                   (1,1)

  2つの三角形で長方形（クワッド）を構成
  ※ OpenGL Core Profile では GL_QUADS が使えないため三角形2枚で代用
```

#### 頂点フォーマットとメモリレイアウト

```
  VBO メモリ上のレイアウト (各 float = 4 bytes):

  オフセット  0    4    8    12   16   20   24   28   ...
           ┌────┬────┬────┬────┬────┬────┬────┬────┬─
           │ x0 │ y0 │ u0 │ v0 │ x1 │ y1 │ u1 │ v1 │ ...
           └────┴────┴────┴────┴────┴────┴────┴────┴─
           │← stride = 16 bytes →│

  glVertexAttribPointer(
      0,          // location = 0
      4,          // 4成分 (x, y, u, v)
      GL_FLOAT,   // 各成分は float
      false,      // 正規化なし
      16,         // stride = 16 bytes (4 floats × 4 bytes)
      0           // オフセット 0 から開始
  )
```

### drawSprite() の1回の呼び出しで起こること

`drawSprite()`（`src/Main.flix:264`）は以下の手順で1枚のスプライトを描画する。

```
  drawSprite(shader, texture, vao, pos, size, color)
  │
  ├── 1. glUseProgram(shader)
  │      シェーダプログラムを有効化
  │
  ├── 2. Model 行列を構築・送信
  │      ┌ size.x  0      0   pos.x ┐
  │      │ 0       size.y 0   pos.y │  → glUniformMatrix4fv()
  │      │ 0       0      1   0     │
  │      └ 0       0      0   1     ┘
  │
  ├── 3. spriteColor を送信
  │      glUniform3f(colorLoc, r, g, b)
  │
  ├── 4. テクスチャをバインド
  │      glActiveTexture(GL_TEXTURE0)      ← テクスチャユニット 0 を選択
  │      glBindTexture(GL_TEXTURE_2D, id)  ← テクスチャを接続
  │
  ├── 5. VAO をバインドして描画
  │      glBindVertexArray(vao)
  │      glDrawArrays(GL_TRIANGLES, 0, 6)  ← 6頂点 = 2三角形 = 1クワッド
  │
  └── 6. VAO をアンバインド
         glBindVertexArray(0)
```

### アルファブレンディング

`main()` 内（`src/Main.flix:521-522`）で有効化される。

```flix
GL11.glEnable(GL11.GL_BLEND);
GL11.glBlendFunc(GL11.GL_SRC_ALPHA, GL11.GL_ONE_MINUS_SRC_ALPHA);
```

**ブレンド式:**

```
  最終色 = SrcColor × SrcAlpha + DstColor × (1 - SrcAlpha)
           ─────────────────     ──────────────────────────
           新しく描画する色       すでにバッファにある色

  例: 半透明の緑ブロック (α = 0.8) を黒背景に描画

  SrcColor = (0.0, 0.63, 0.0),  SrcAlpha = 0.8
  DstColor = (0.0, 0.0, 0.0)    ← 背景（黒）

  最終色 = (0.0, 0.63, 0.0) × 0.8 + (0.0, 0.0, 0.0) × 0.2
         = (0.0, 0.504, 0.0)

  例: 同じブロックを背景テクスチャ（青空）の上に描画

  SrcColor = (0.0, 0.63, 0.0),  SrcAlpha = 0.8
  DstColor = (0.5, 0.7, 1.0)    ← 背景テクスチャの色

  最終色 = (0.0, 0.63, 0.0) × 0.8 + (0.5, 0.7, 1.0) × 0.2
         = (0.0, 0.504, 0.0) + (0.1, 0.14, 0.2)
         = (0.1, 0.644, 0.2)    ← 背景が少し透けて見える
```

これにより、PNG のアルファチャンネルを活用した半透明描画が実現される。
ブロックやパドルの角の丸み、ボールの円形がきれいに表示される仕組みである。

---

## 10. ゲームループの構造

### 末尾再帰（@Tailrec）によるスタック安全なループ

`gameLoop()`（`src/Main.flix:550`）は `@Tailrec` アノテーションが付いた
末尾再帰関数である。

```flix
@Tailrec
def gameLoop(window, state, textures, shader, vao): Unit \ IO =
    GLFW.glfwPollEvents();
    let escPressed = GLFW.glfwGetKey(window, 256) == 1;
    let windowClosing = GLFW.glfwWindowShouldClose(window);
    if (escPressed or windowClosing) {
        println("Closing game...")
    } else {
        render(state, textures, shader, vao);
        GLFW.glfwSwapBuffers(window);
        gameLoop(window, state, textures, shader, vao)  // ← 末尾再帰呼出し
    }
```

Flix コンパイラは末尾再帰を最適化し、内部的に `while` ループ相当のバイトコードに
変換する。そのためスタックオーバーフローは発生しない。

### 1フレームの処理

```
  ┌──────────────────────────────────────────────────┐
  │                 gameLoop()                       │
  │                                                  │
  │  1. glfwPollEvents()                             │
  │     OS からのイベント（キー入力、ウィンドウ操作等）│
  │     を取得してコールバックに配信                   │
  │                                                  │
  │  2. glfwGetKey(GLFW_KEY_ESCAPE)                  │
  │     ESC キーが押されているか確認                   │
  │                                                  │
  │  3. glfwWindowShouldClose()                      │
  │     ウィンドウの × ボタンが押されたか確認          │
  │                                                  │
  │  4. render(state, textures, shader, vao)          │
  │     現在の状態をもとにフレームを描画               │
  │     （詳細はセクション11参照）                     │
  │                                                  │
  │  5. glfwSwapBuffers(window)                      │
  │     バックバッファとフロントバッファを交換          │
  │     ─→ 描画結果が画面に表示される                 │
  │                                                  │
  │  6. gameLoop(...) ← 末尾再帰で次フレームへ        │
  └──────────────────────────────────────────────────┘
```

### ダブルバッファリング

`glfwSwapInterval(1)`（`src/Main.flix:511`）により VSync が有効化され、
ディスプレイのリフレッシュレート（通常 60Hz）に同期する。

```
  フロントバッファ（画面に表示中）    バックバッファ（描画先）
  ┌──────────────────┐              ┌──────────────────┐
  │                  │              │                  │
  │   前フレームの    │              │   現フレームを    │
  │   描画結果       │              │   描画中         │
  │                  │              │                  │
  └──────────────────┘              └──────────────────┘
           ↑                                 │
           │        glfwSwapBuffers()        │
           └─────────── swap ◄──────────────┘

  swap 後:
  ┌──────────────────┐              ┌──────────────────┐
  │                  │              │                  │
  │   現フレームの    │              │   次フレームの    │
  │   描画結果 ★表示 │              │   描画先         │
  │                  │              │                  │
  └──────────────────┘              └──────────────────┘

  ※ シングルバッファだと描画途中が画面に見えてしまい、
    ちらつき (flickering) が発生する。
    ダブルバッファリングにより、完成したフレームだけが表示される。
```

---

## 11. レンダリング1フレームの描画順序

`render()`（`src/Main.flix:451`）は**ペインターアルゴリズム**で描画する。
奥のものから手前のものへ順に描画し、後から描いたものが前面に表示される。

### 描画順序

```
  描画順序  対象                    テクスチャ          色
  ─────────────────────────────────────────────────────────────────
  1 (最奥)  背景                   background.jpg     (1,1,1) 白
  2         ブリック（破壊済み除く） block/block_solid   タイル色
  3         パドル                  paddle.png         (1,1,1) 白
  4 (最前)  ボール                  awesomeface.png    (1,1,1) 白
```

### ゲーム画面レイアウト

```
  (0,0)                                              (800,0)
  ┌──────────────────────────────────────────────────────┐
  │                                                      │
  │  ┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┐ │
  │  │████│████│████│████│████│████│████│████│████│████│ │ ← ブリック
  │  ├────┼────┼────┼────┼────┼────┼────┼────┼────┼────┤ │   (上半分に配置)
  │  │████│████│████│████│    │████│████│████│████│████│ │
  │  ├────┼────┼────┼────┼────┼────┼────┼────┼────┼────┤ │
  │  │████│████│████│████│████│████│████│████│████│████│ │
  │  └────┴────┴────┴────┴────┴────┴────┴────┴────┴────┘ │
  │                                                      │
  │                        (画面高さ/2)                   │ ← 300px
  │         ~~~~~~~~~ 背景テクスチャ ~~~~~~~~~~           │
  │                                                      │
  │                                                      │
  │                         ◯                            │ ← ボール (y=555)
  │                    ┌──────────┐                       │ ← パドル (y=580)
  │                    │  paddle  │                       │   100×20 px
  │                    └──────────┘                       │
  └──────────────────────────────────────────────────────┘
  (0,600)                                            (800,600)
```

### Z-order と描画順序

OpenGL 2D 描画ではデプスバッファ (Z-buffer) を使わず、
描画順序だけで前後関係を制御する。

```
  フレームバッファの構築過程:

  Step 1: 背景を描画             Step 2: ブリックを描画
  ┌──────────────────┐          ┌──────────────────┐
  │ ░░░░░░░░░░░░░░░░ │          │ ████████████████ │
  │ ░░░ 背景 ░░░░░░░ │          │ ████ブリック████ │
  │ ░░ テクスチャ ░░░ │          │ ░░░░░░░░░░░░░░░░ │
  │ ░░░░░░░░░░░░░░░░ │          │ ░░░░░░░░░░░░░░░░ │
  └──────────────────┘          └──────────────────┘

  Step 3: パドルを描画           Step 4: ボールを描画
  ┌──────────────────┐          ┌──────────────────┐
  │ ████████████████ │          │ ████████████████ │
  │ ████ブリック████ │          │ ████ブリック████ │
  │ ░░░░░░░░░░░░░░░░ │          │ ░░░░░░░░░░░░░░░░ │
  │ ░░░ ▓▓▓▓▓▓ ░░░░ │          │ ░░░░░ ◯ ░░░░░░░ │
  └──────────────────┘          │ ░░░ ▓▓▓▓▓▓ ░░░░ │
                                └──────────────────┘
```

---

## 12. Flix言語の特徴的な使い方

### 不変データ構造によるゲーム状態管理

`GameState` はすべて不変（immutable）なレコードで構成される。
ゲーム状態を更新するには、新しいレコードを生成する。

```flix
// Flix ではレコードのフィールドは直接変更できない
// 新しいレコードを作って返す（関数型のスタイル）
let newState = {ballPos = {x = newX, y = newY} | state};
```

現在のコードではゲーム状態は変化しない（入力処理・物理演算は未実装）ため、
`gameLoop` は同じ `state` を渡し続ける。

### エフェクトシステム（`\ IO`）

Flix は副作用をエフェクトとして型レベルで追跡する。

```flix
// 純粋関数（副作用なし）
def tileColor(tileType: Int32): Vec3 = ...

// IO エフェクトを持つ関数
def loadTexture(path: String, alpha: Bool): Int32 \ IO = ...

// テスト用エフェクト
def testFoo(): Unit \ Assert = ...
```

`\ IO` はその関数がファイル読み込み、OpenGL 呼び出し、コンソール出力など
の副作用を持つことを明示している。

### パターンマッチング

リスト処理に多用されている（`src/Main.flix:350-356, 368-386`）。

```flix
def buildBricks(rows: List[List[Int32]], ...): List[GameObject] =
    match rows {
        case row :: rest =>    // 先頭要素と残りに分解
            ...
        case Nil =>            // 空リスト
            Nil
    }
```

### 末尾再帰最適化

`@Tailrec` アノテーションにより、コンパイラが末尾再帰を検出・最適化する。
最適化できない場合はコンパイルエラーになるため、安全性が保証される。

```flix
@Tailrec
def gameLoop(...): Unit \ IO =
    ...
    gameLoop(...)  // ← 関数の最後の式が自分自身の呼び出し = 末尾再帰
```

### Java Interop（import による LWJGL 呼び出し）

Flix は JVM 上で動作するため、Java ライブラリを直接インポートして使える
（`src/Main.flix:4-17`）。

```flix
import org.lwjgl.opengl.GL11       // Java クラスを Flix にインポート

// Java の static メソッドを Flix から直接呼び出し
GL11.glClear(GL11.GL_COLOR_BUFFER_BIT)
```

インポートはモジュールのトップレベルに記述する必要がある。

---

## 13. 技術スタック図

```
  ┌─────────────────────────────────────────────────────────┐
  │                    Flix ソースコード                       │
  │                   (src/Main.flix)                         │
  │         関数型プログラミング、エフェクトシステム             │
  └───────────────────────┬─────────────────────────────────┘
                          │ import / Java Interop
                          ▼
  ┌─────────────────────────────────────────────────────────┐
  │                  JVM (Java 21)                          │
  │              Flix コンパイラが生成した                      │
  │              JVM バイトコードを実行                        │
  └───────────────────────┬─────────────────────────────────┘
                          │
                          ▼
  ┌─────────────────────────────────────────────────────────┐
  │                 LWJGL 3.3.4                             │
  │    Lightweight Java Game Library                        │
  │    ┌──────────┐ ┌──────────┐ ┌──────────┐              │
  │    │lwjgl-glfw│ │lwjgl-    │ │lwjgl-stb │              │
  │    │          │ │opengl    │ │          │              │
  │    └────┬─────┘ └────┬─────┘ └────┬─────┘              │
  └─────────┼────────────┼────────────┼─────────────────────┘
            │ JNI        │ JNI        │ JNI
            ▼            ▼            ▼
  ┌──────────────┐ ┌───────────┐ ┌──────────────┐
  │ GLFW 3.3     │ │ OpenGL    │ │ STB Image    │
  │ (ネイティブ)  │ │ (ネイティブ)│ │ (ネイティブ)  │
  │              │ │           │ │              │
  │ ウィンドウ管理│ │ 3D描画API │ │ 画像デコード  │
  │ キー入力     │ │           │ │ JPG/PNG→    │
  │ イベント処理  │ │           │ │   ピクセル   │
  └──────┬───────┘ └─────┬─────┘ └──────────────┘
         │               │
         ▼               ▼
  ┌─────────────────────────────────────────────────────────┐
  │                   OS / ドライバ                          │
  │          macOS: Cocoa + Metal→OpenGL 互換レイヤー        │
  └───────────────────────┬─────────────────────────────────┘
                          │
                          ▼
  ┌─────────────────────────────────────────────────────────┐
  │                     GPU                                 │
  │            頂点シェーダ・フラグメントシェーダ実行          │
  │            テクスチャサンプリング                         │
  │            フレームバッファへのピクセル書き込み            │
  └─────────────────────────────────────────────────────────┘
```

### LWJGL の役割

LWJGL (Lightweight Java Game Library) は Java/JVM から
ネイティブグラフィックスライブラリを呼び出すための**バインディング層**である。
JNI (Java Native Interface) を通じて C 言語で書かれたライブラリを呼び出す。

本プロジェクトでは以下の 3 モジュールを使用:

| モジュール | 役割 | 主な関数 |
|-----------|------|---------|
| lwjgl-glfw | ウィンドウ・入力管理 | `glfwCreateWindow`, `glfwPollEvents` |
| lwjgl-opengl | 3D グラフィックス描画 | `glDrawArrays`, `glTexImage2D` |
| lwjgl-stb | 画像ファイル読み込み | `stbi_load`, `stbi_image_free` |

macOS (Apple Silicon) 用のネイティブライブラリは
`lib/` ディレクトリに配置されている（`*-natives-macos-arm64.jar`）。

---

*このドキュメントは `src/Main.flix` (Flix 0.71.0) のソースコードに基づいて作成されたものである。*
