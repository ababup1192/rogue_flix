# Breakout Flix

Flix で実装した Breakout（ブロック崩し）ゲーム。LearnOpenGL チュートリアルを忠実に再現し、LWJGL + OpenGL 3.3 Core Profile でレンダリング。

## 必要環境

- devbox（推奨）
- JDK 21
- macOS (Apple Silicon)

## 実行方法

```bash
devbox shell
flix run
```

## テスト

```bash
flix test
```

## プロジェクト構造

```
src/
  Main.flix          - エントリーポイント・ゲームループ・レンダリング
test/
  TestMain.flix      - レベルパース・初期配置のテスト
levels/
  one.lvl ~ four.lvl - LearnOpenGL 形式のレベルデータ
textures/
  background.jpg     - 背景画像
  block.png          - 通常ブロック
  block_solid.png    - 破壊不可ブロック
  paddle.png         - パドル
  awesomeface.png    - ボール
```

## 技術スタック

- **Flix 0.71.0** - 関数型プログラミング言語
- **LWJGL 3.3.4** - OpenGL / GLFW / STB バインディング
- **OpenGL 3.3 Core Profile** - シェーダーベースのスプライトレンダリング

## 操作方法

- **ESC** / ウィンドウ閉じる - 終了
