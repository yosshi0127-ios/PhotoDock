# アーキテクチャと設計の理由

「**なぜその構造なのか**」の解説です。ルールの一覧は [`CLAUDE.md`](../CLAUDE.md)、プロダクトの方針と決定事項は [`product-brief.md`](product-brief.md) にあります。

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
    FullScan/
    FlaggedPhotos/
    PhotoDetail/
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

## ビルドとテスト（補足）

プロジェクトは **`PhotoDock/PhotoDock.xcodeproj`（repo ルートの1段下）**、ソースは隣の `PhotoDock/PhotoDock/`。repo ルートから叩くときは `-project` が必須。

```bash
xcodebuild build -project PhotoDock/PhotoDock.xcodeproj -scheme PhotoDock \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'
xcodebuild test  -project PhotoDock/PhotoDock.xcodeproj -scheme PhotoDock \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'
```

destination を iOS 26.2 に固定しているのは、deployment target が 26.0 で、手元にある最も低い iOS 26 ランタイムが 26.2 だから（**最低ラインで検証する**）。Xcode の ⌘U はツールバーで選んだ実行先を使うので、コミット前は CLI で一度確認する。

規約の機械検査（CI でも同じものが走る）:

```bash
swiftlint lint --strict --quiet && scripts/arch-check.sh   # exit 0 以外 = 違反あり
```

- `.swiftlint.yml` の custom_rules … 層違反・注入点違反・Policy の純粋性（スタイルルールは無効）
- `scripts/arch-check.sh` … DI 3値・1依存1ファイル・protocol の登録漏れ・liveValue が本番実装

ビルド設定: iOS 26.0（2026-09-12 に 18.0 から引き上げ。理由は brief の「設計方針」）/ Swift 6.0 / `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` / iPhone は縦向き固定。Info.plist は `PhotoDock/PhotoDock/Info.plist`（`BGTaskSchedulerPermittedIdentifiers` だけ。他のキーは `INFOPLIST_KEY_*` で生成し、ビルド時に合成される）。

## 現在の実装状況

**ホーム → 全量スキャン（進捗） → 所見のある写真グリッド → 写真詳細（枠 + 所見リスト）まで一本の線で繋がっている。** 結果は SwiftData に記録され、2回目以降は新しい写真だけ診断する。写真詳細を開いている間も診断は続く。アプリを離れても続ける仕組み（`BGContinuedProcessingTask`）は入っているが、**背景で GPU を使う entitlement が個人チームでは付けられないため、いまは申告が拒否されて前面のみ**（有料プログラム加入後に自動で有効になる）。

依存は7本、いずれも3点セット + live スモークで担保:

| 依存 | 役割 | 段 |
|---|---|---|
| `photoLibrary` | メタデータ全件列挙 + 権限 | 第1段 |
| `pixelSource` | 画像バイト列（iCloud 判定込み）+ 一覧用サムネイル | 第2段 |
| `ocr` | 文字認識（座標変換込み）。前段に文字矩形の検出を置き、文字のない写真では OCR を省く。**読めなかったときは空配列ではなく失敗を返す**（「文字が無かった」と混ぜると、見ていない写真が診断済み・所見なしとして記録される） | 第2段 |
| `faceDetection` | 顔の位置と向き（写り込み判定の入力）。**シミュレータでは検出ゼロで続行** | 第2段 |
| `scanRecords` | スキャン済み記録の保存（SwiftData）。所見ゼロも記録し、2回目以降は新しい写真だけ診断する | 第2段 |
| `network` | いま通信してよい回線か（Wi-Fi・低データモードでない）。iCloud の写真を取り寄せる前に1回だけ見る | 第2段 |
| `continuedProcessing` | 前面で始めた診断をアプリを離れても続けたいと OS に申告する（`BGContinuedProcessingTask`）。診断する写真があるときだけ申告し、1枚ごとに進捗を報告。背景の GPU（`.gpu`）を要求し、**拒否されたら nil を返して診断は前面だけで続く**（Vision が背景で GPU 無しでは止まるため） | 第2段 |

- Policy 3本: `LibraryInventoryPolicy`（第1段の集計）/ `FindingPolicy`（文字と顔 → 所見・severity・マスク）/ `ScanSummaryPolicy`（第2段の逐次集計）
- UseCase 5本: `ScanLibraryMetadataUseCase` / `ScanImageUseCase`（画像1枚 → 所見。OCR と顔検出を並行に回して Policy へ）/ `ScanPhotoUseCase`（ライブラリの1枚。`ScanImageUseCase` に委譲）/ `ScanLibraryPhotosUseCase`（全量。並列2・完了順に流す。診断する写真があれば OS に継続を申告し、1枚ごとに進捗を報告）/ `LoadThumbnailUseCase`
- 画面4つ: 診断ホーム / 全量スキャン（**精密のみ**。実機でクイックの 1.63 倍で済むためプリセットは出さない） / 所見のある写真グリッド / 写真詳細（一覧からは**記録を表示するだけで再検査しない**。PhotosPicker の1枚だけ精密で診断）
- 保存: `SwiftDataScanRecordRepository`。所見ゼロも「スキャン済み」として記録し、2回目以降は新しい写真の分だけ診断する。本文（マスク済み文字列）は保存しない
- ユニットテスト169件。座標変換は合成画像を本物の Vision に通して固定してある
- 実測（シミュレータ・162枚）: 並列化は効かない（1→2 で 7%、8 で破綻）。OCR の前段で 3.1 倍速。詳細は brief

**残り: 顔検出の失敗を「検出ゼロ」と区別する / 対処（削除・非表示）/ 経路チップ / Foundation Models による credential の意味判定（実機のみ）。** 写り込み顔の閾値は仮置きで、実機のカメラロールで調整する。バックグラウンド継続は有料プログラム加入後に entitlement「Background GPU Access」を付けて有効化する（`UIBackgroundModes` は不要だった）。
