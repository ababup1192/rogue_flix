## 環境

- devbox shell で開発環境に入る（JDK 21 必須）
- `flix run` / `flix test` / `flix build` で実行
- bin/flix.jar は Flix 0.71.0（devbox には最新がないため手動ダウンロード）

## Flix バージョン更新

```bash
curl -L -o bin/flix.jar https://github.com/flix/flix/releases/download/vX.XX.X/flix.jar
```

## 変更後の確認

コード変更後は必ず以下を両方実行すること：
1. `flix test` - テストが通ることを確認
2. `flix run`  - 実際に動作することを確認

## Flix コーディングルール

**重要**: Flix コードを書く前に必ず以下を参照すること（WebFetch で取得）
https://doc.flix.dev/for-llms.html

ここに書いてあるルールは決して破らないこと。

## Flix 0.71.0 固有の注意点（公式ドキュメントに載っていない）

### Channel API
- Javaのatomic変数を使いたくなったら見ること
- `Channel.buffered(size)` - Region を受け取らない、サイズのみ
- 戻り値は `(Sender[t], Receiver[t])` のタプル
- エフェクトは `Chan` と `NonDet`
- ここを見てからコードを書くこと https://doc.flix.dev/concurrency.html?highlight=Channel#communicating-with-channels

### try-catch での Java 例外
- import してから使う（`##java.io.IOException` ではなく `IOException`）

### 予約語に注意
- `handler` は予約語（エフェクトハンドラで使用）
- import文, 変数名として使うとパースエラーになる
- 代わりの英単語を使うか、~~Handlerのように2単語以上で命名する

```flix
// NG: handler は予約語
case Some((handler, params)) => ...

// OK: 別の単語 を使う
case Some((action, params)) => ...
```

## テストの書き方

### @Test 関数の戻り値
- `@Test` 関数は必ず `Unit` を返す必要がある
- Assertモジュールを使って、assertionをする

```flix
// OK: Assert.assertTrue でラップ
@Test
def testFoo(): Unit \ Assert =
    Assert.assertTrue(someCondition)
```

### interlop Java
- Javaのimportをするときは、モジュールのトップレベルに書く必要がある
- importを書かずに java.Math.abs() のようには呼び出せない

## 外部 JAR の利用

予約語（`handler` 等）を含むパッケージは Java ラッパー経由で使う。

1. `flix.toml` に Maven 依存追加 → `flix build` で `lib/cache/` にダウンロード
2. Java ラッパーをコンパイルして `lib/external/xxx.jar` に配置
3. `flix.toml` の `[jar-dependencies]` に `"xxx.jar" = "url:file://local"` を追加
4. Flix から `import mypkg.MyClass` で利用

