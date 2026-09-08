# PhotoDock / 写真ドック

カメラロールの棚卸し診断 iOS アプリ。全量スキャンで「見られたらまずい写真」を洗い出し、対処まで導く。

- **プロダクトの方針・決定事項は [`docs/product-brief.md`](docs/product-brief.md) が原本**。作業前に必ず読む
- **守るべきルールと作業手順は [`CLAUDE.md`](CLAUDE.md)**（機械検査つき）
- このファイルは「**なぜその構造なのか**」の解説。ルールの一覧ではない

## アーキテクチャ

クリーン3層 + swift-dependencies による DI。[SwiftArchitectureSample](https://github.com/yosshi0127-ios/SwiftArchitectureSample) に基づく。

```
Features ──▶ Core ◀── Infrastructure
                 ▲
              App/DI      ← ここだけが両側を知り、結線する
```

厳格なのは**依存の向き**と**注入点**の2つだけで、それ以外は普通の MVVM + 軽い UseCase 層。

| 層 | 中身 | 持てる依存 |
|---|---|---|
| `Core/Models` | ドメインの値型 | — |
| `Core/Services` | 能力（〜する）の protocol | — |
| `Core/Repositories` | 永続化（〜を覚える）の protocol | — |
| `Core/Policy` | 判断（入力 → 結論）の純粋関数 | — |
| `Infrastructure/` | protocol の実装。実 I/O | 実 I/O |
| `Features/UseCases` | 段取り。具体 struct | `@Dependency`（**唯一の場所**） |
| `Features/Screens/<画面>` の State | `@MainActor @Observable`。画面の状態 | UseCase のみ |
| `Features/Screens/<画面>` の View | SwiftUI | なし（State を生成するだけ） |
| `App/DI` | 依存の登録（3値） | 両側を知る |
| `Support/Mocks` | Stub / Unimplemented | — |

### Features の中の分け方

```
Features/
  UseCases/          段取り。画面をまたいで共有する
  Screens/
    Home/            1画面 = 1ディレクトリ（State / View / その画面専用の部品）
    PhotoCheck/
```

機能名（Scan / Setting …）では切らず、**`UseCases` と `Screens` の2つだけで切る**。理由は3つ。

- 機能の境界は揺れる。「権限がないときの画面は Scan 機能か」「設定は機能なのか」は決めても後から動くので、ディレクトリを作り直し続けることになる
- **ディレクトリは何も強制しない。** 同一モジュールなので `Features/Scan/` を作っても隣の `Features/Setting/` から普通に参照できる。本当に境界を効かせたいなら SPM モジュールに切るしかない
- ファイルを探すときの手がかりは「どの画面か」で、「どの機能か」ではない

UseCase は**画面間では共有する**（`ScanImageUseCase` は診断ホームと1枚チェックの両方から呼ばれる）。`Core/Services` と `Core/Policy` はアプリ全体の共有物。

「この処理はどこに置くか」で迷ったときの対応:

| 迷い | 置き場所 |
|---|---|
| 2つの画面が同じ段取りを踏む | `UseCases/` の1本を両方から呼ぶ（コピーしない） |
| 段取りの中に判断（危険か・どう数えるか）が混ざっている | 判断を `Core/Policy` に下げる |
| 表示のための計算しかしていない | その画面の State |

なお `@Dependency` を許可する lint の例外は **`UseCases?/` というパスの正規表現**でしかない。UseCase をこの名前以外のディレクトリに置くと `dependency_only_in_usecase` で落ちる。

### `Core/` が Foundation しか import できない理由

Core はドメインの言葉とルールだけを持つ。Apple のフレームワークが混ざると、そのルールを別環境（コマンドラインのツール、将来の別プラットフォーム）で動かせなくなる。

具体的な帰結として、**CoreLocation も import できない**。だから緯度経度は独自の `GeoCoordinate` を定義し、`CLLocation` からの変換は Infrastructure の1箇所に閉じる。座標系のバグを型で殺すのが目的で、`Region`（左上原点・0...1 正規化）も同じ発想。

同じ理由で、Core の protocol に `@MainActor` を書かない。隔離は**実装側の都合**であって契約ではない。

### 判断は Policy、実行は UseCase

「危険かどうか」「どの順で処理するか」といった判断は、I/O を持たない純粋関数として `Core/Policy` に置く。フレームワークを起動せずに全網羅テストできることが Policy の価値。

対して UseCase は**順序だけ**を持つ。たとえば `ScanLibraryMetadataUseCase` は「権限を確かめ → 列挙し → Policy に集計させる」という順番の知識しか持たず、数え方も判定基準も持たない。UseCase の行数が少ないのは正しい状態。

### 依存の追加は3点セット

```
Core の protocol → Infrastructure の実装 → App/DI/DependencyValues+<名前>.swift（3値）
```

3つ揃っていないと `scripts/arch-check.sh` が落ちる。実装名は「**具体技術 + protocol 名**」（例: `PhotoKitPhotoLibraryService`）。能力の名前に技術を入れない — PhotoKit をやめても Core の型名が変わらないようにするため。

### DI の3値

| 実行文脈 | 解決される値 | 中身 |
|---|---|---|
| アプリ実行 | `liveValue` | 本番実装 |
| Xcode Preview | `previewValue` | Stub（決定的な固定データ） |
| テスト | `testValue` | Unimplemented（呼ばれたら `fatalError`） |

`testValue` がクラッシュするのは意図的。テストで `withDependencies` の上書きを忘れたとき、**静かに本物を呼ぶ事故**を防ぐ。落ちれば必ず気づく。

`previewValue` は「副作用ゼロ」だけでなく「**Preview の見た目が成立する値**」であること。`StubPhotoLibraryService` が 1,240 枚の固定データを返すのは、4桁の数字が入る画面のレイアウトを確認するため。乱数と現在時刻は使わない（Preview が毎回変わると信頼できない道具になる）。

### なぜ UseCase を protocol にしないか

差し替える必要がないから。差し替え境界（I/O）は既に protocol 化されていて、テストは `withDependencies` で**中の依存**を差し替えて本物の UseCase を検証する。UseCase は「差し替える対象」ではなく「テストされる対象」。

DIP は「差し替えが要る境界」を抽象化する原則であって、全部を protocol にすることではない。

## テスト方針

| 対象 | 書き方 |
|---|---|
| Policy | ただの関数テスト。`withDependencies` も非同期も不要 |
| UseCase | `withDependencies` で Spy を挿し、**呼ばれた回数と順序**を検証 |
| liveValue | `LiveDependenciesSmokeTests` で解決できることと型を固定 |

### `@Dependency` は「生成時点」の文脈を捕捉する

そのため、テストでは対象を **`withDependencies` の中で生成する**。

```swift
let outcome = await withDependencies {
    $0.photoLibrary = spy
} operation: {
    let useCase = ScanLibraryMetadataUseCase()   // ← 必ずこの中
    return await useCase()
}
```

外で生成すると Unimplemented を掴んだままになり落ちる。

### Spy は actor で書く

呼び出し回数という可変状態を持つのに protocol は `Sendable` を要求する。`final class` + `@unchecked Sendable` + ロックでも書けるが、**隔離をコンパイラに任せられる** `actor` を採る。Core の protocol のメソッドを全部 `async` にしてあるので、actor が要件を満たせる。

### liveValue はテストで踏まれない

`previewValue` / `testValue` は Preview とテストが毎回踏むので壊れれば気づくが、`liveValue` は誰も踏まない。「live にうっかり Stub を登録した」事故を捕まえるために、静的検査（`arch-check.sh` が右辺の型名を見る）と実行時検査（`LiveDependenciesSmokeTests`）の両方を置いている。

## ビルドとテスト

プロジェクトは **`PhotoDock/PhotoDock.xcodeproj`（repo ルートの1段下）**、ソースは隣の `PhotoDock/PhotoDock/`。repo ルートから叩くときは `-project` が必須。

```bash
xcodebuild build -project PhotoDock/PhotoDock.xcodeproj -scheme PhotoDock \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'
xcodebuild test  -project PhotoDock/PhotoDock.xcodeproj -scheme PhotoDock \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'
```

destination を iOS 18.4 に固定しているのは、deployment target が 18.0 なので**最低ラインで検証する**ため。Xcode の ⌘U はツールバーで選んだ実行先を使うので、コミット前は CLI で一度確認する。

規約の機械検査（CI でも同じものが走る）:

```bash
swiftlint lint --strict --quiet && scripts/arch-check.sh   # exit 0 以外 = 違反あり
```

- `.swiftlint.yml` の custom_rules … 層違反・注入点違反・Policy の純粋性（スタイルルールは無効）
- `scripts/arch-check.sh` … DI 3値・1依存1ファイル・protocol の登録漏れ・liveValue が本番実装

ビルド設定: iOS 18.0 / Swift 6.0 / `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` / iPhone は縦向き固定。

## 踏んだ罠（同じ穴を掘らないために）

**SourceKit の diagnostics は誤検知が多い。** `Cannot find type ...` や `No such module 'Dependencies'` が同一モジュール内の型に対して頻繁に出る。**真実は xcodebuild の結果だけ**。

**ユニットテストはホストアプリのプロセスで動く。** `TEST_HOST` が指定されているので、テスト実行時にアプリが普通に起動し、`WindowGroup` の中身が組まれ、View の `.task` が発火する。そこで依存を触るとテスト文脈なので `testValue`（Unimplemented）を踏み、**テストが1件も走る前にプロセスごと死ぬ**。対策として `PhotoDockApp` はユニットテスト時に画面を組まない（`NSClassFromString("XCTestCase")` で判定）。UI テストは別プロセスから起動するので該当しない。

**ディレクトリ名が規約のアンカーになっている。** `.swiftlint.yml` と `arch-check.sh` はパスの正規表現・実パスでルールを引くので、名前が1文字違うと**エラーではなく沈黙で検査が消える**。`Core/Services`・`Core/Policy`・`Features/`・`App/DI` は実際にこの綴りでないと引っかからない（`UseCases?` だけは単複どちらでも通るようにしてある）。加えて macOS は大文字小文字を区別しないので、`APP/DI` のような誤りは**ローカルでは通り Linux の CI だけ落ちる**（git のインデックス側の case も `git rm --cached -f` で直す必要がある）。

**`nonisolated async` は呼び出し元の隔離を引き継ぐ → 重い実装には `@concurrent` を付ける。** `SWIFT_APPROACHABLE_CONCURRENCY = YES`（Swift 6.2 の `NonisolatedNonsendingByDefault`）のため、`@MainActor` の State から `await` したサービスのメソッドは**メインスレッドで走る**。以前の Swift は自動でグローバルエグゼキュータへ退避していたので、挙動が逆転している。

実測で確認した事実（`pthread_main_np()` でログ）:

| 実装 | 実行スレッド |
|---|---|
| `func fetchAllAssetMetadata() async` | **main**（数万枚の列挙が UI を塞ぐ） |
| `@concurrent func fetchAllAssetMetadata() async` | main 以外 |

`@concurrent` を付けた実装は `nonisolated async` の protocol 要件を問題なく満たす（Core の protocol に隔離を書けない恒常ルール3と両立する）。

**運用ルール: 重い同期処理を含むサービス実装のメソッドにだけ `@concurrent` を付ける。** 安いメソッド（`currentAccess()` のような即答する読み取り）には付けない — 不要なスレッド跳躍を減らすことが Swift 6.2 のこの変更の目的なので、全部に付けると台無しになる。第2段で増える `pixelSource` / `ocr` / `codes` はいずれも重い側。

なお `Thread.isMainThread` と `Thread.current` は Swift 6 の async 文脈では使用禁止（タスクがスレッドを移りうるため意味が曖昧になる）。計測には `pthread_main_np()` を使う。

**Vision の顔検出はシミュレータで動かない**（`Could not create inference context` / code 9）。環境依存の検出器は「検出ゼロで続行」に設計する。

## 現在の実装状況

**第1段スキャン（メタデータ全件列挙）は画面まで完成。第2段（1枚の診断）は UseCase まで完成、画面はこれから。**

依存は3本、いずれも3点セット + live スモークで担保:

| 依存 | 役割 | 段 |
|---|---|---|
| `photoLibrary` | メタデータ全件列挙 + 権限 | 第1段 |
| `pixelSource` | 画像バイト列（iCloud 判定込み） | 第2段 |
| `ocr` | 文字認識（座標変換込み） | 第2段 |

- Policy 2本: `LibraryInventoryPolicy`（集計）/ `FindingPolicy`（分類・severity・マスク）
- UseCase 3本: `ScanLibraryMetadataUseCase`（第1段）/ `ScanImageUseCase`（画像データ1枚 → 所見）/ `ScanPhotoUseCase`（ライブラリの1枚 → 所見。中身は `ScanImageUseCase` に委譲）
- 診断ホームの State / View（第1段の結果）。実機で権限ダイアログの文言と実データの集計、ダーク/ライト両モードを確認済み
- ユニットテスト53件。座標変換は合成画像を本物の Vision に通して固定してある

**残り: 1枚チェックの画面 / 所見インデックスの永続化 / 全量スキャン（N 並列・進捗）。** brief の Phase 1 の本体。
