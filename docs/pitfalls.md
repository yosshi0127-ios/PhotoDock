# 踏んだ罠

開発中に実際にはまった問題と、その原因・直し方の記録です。同じ穴を掘らないために残しています。

**SourceKit の diagnostics は誤検知が多い。** `Cannot find type ...` や `No such module 'Dependencies'` が同一モジュール内の型に対して頻繁に出る。**真実は xcodebuild の結果だけ**。

**逆に「通常ビルドとテストは通るのに Preview だけ壊れる」書き方がある。** Preview は `__designTimeSelection` を挟むコード変換を行うので、そこで曖昧さが出ると Preview のビルドだけが失敗する。**`xcodebuild test` が green でも気づけない**ので、View を触ったら Preview を描画して確認する。

| 壊れる書き方 | 直し方 |
|---|---|
| `case let .loaded(.scanned(access, inventory))` | associated value のラベルを省略しない |
| `Button("ラベル", action: メソッド名)` | `Button("ラベル") { メソッド名() }` とクロージャで包む |

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

**`addTaskUnlessCancelled` は親タスクのキャンセルでは追加を拒否しない。** `AsyncStream` + `TaskGroup` で「N 並列を保ちながら完了順に流す」形を書くとき、消費側の離脱で処理を止めるには**自分で `Task.isCancelled` を見て `break` する**必要がある。

実測（200枚を2並列、5枚読んで離脱）:

| 補充の書き方 | 離脱後 |
|---|---|
| `group.addTask` | **200枚すべて処理**（止まらない） |
| `group.addTaskUnlessCancelled` | **50枚以上処理して増え続ける**（うち44枚はキャンセル済みで開始） |
| `if Task.isCancelled { break }` | **8枚で停止**（待っても増えない） |

子タスクには `Task.isCancelled == true` が伝播しているのに、グループへの追加は通る。`Task.sleep` はキャンセルで即座に返るので、**キャンセル後ほど速く回って被害が大きくなる**。テストの Spy も `Task.sleep` を使うと「止まった」と「速く走り切った」を区別できないので、待ち切る実装にしてある。

**Vision の顔検出はシミュレータで動かない**（`Could not create inference context` / code 9）。環境依存の検出器は「検出ゼロで続行」に設計する。

**Foundation Models（オンデバイス LLM）もシミュレータで動かない。しかも `availability` は `.available` と嘘をつく。** 実際に `respond` すると safety モデル（`com.apple.fm.language.instruct_300m.safety`）が見つからず `GenerationError` になる。macOS 26.5 実機では動く。availability の確認だけでなく、呼び出しの失敗も握って続行する設計が要る。

**フォルダ同期グループの中に Info.plist を置くと「Multiple commands produce Info.plist」で落ちる。** Xcode 16 以降の同期グループはフォルダ内の全ファイルをターゲットに入れるので、`INFOPLIST_FILE` に指定した plist が Copy Bundle Resources にも入って衝突する。Xcode が GUI で plist を作るときと同じく、pbxproj に `PBXFileSystemSynchronizedBuildFileExceptionSet`（`membershipExceptions = (Info.plist)`）を足して除外する。

**View の `.task` は子画面を push しただけでキャンセルされる。** NavigationStack で詳細を開くと親の `onDisappear` が呼ばれ、`.task` も止まる。数十分かかる診断をここに乗せると、写真詳細を開いた瞬間に止まる。State が自前の `Task` を持ち、View は `onAppear` から同期で始めるだけにする。さらに、View がその Task の終わりを `await` すると State を掴み続けて画面を閉じても捨てられないので、開始は同期で返し、終わりを待ちたいテストは `waitUntilSettled()` を使う。

**`@MainActor` クラスの `deinit` は nonisolated なので、隔離された stored property に触れない**（`scanTask?.cancel()` が「main actor-isolated property can not be referenced from a nonisolated context」）。`isolated deinit`（Swift 6.1 / iOS 18.4+）にすると触れる。あわせて、Task が `self` を強く持つと deinit が来ないので、ループ内の `self` は弱参照にする。

**`BGTask` は Sendable でないので actor から actor へ渡せない**（「sending 'task' risks causing data races」）。OS の launch handler から受け取る1箇所だけ `nonisolated(unsafe) let` で送り、以後は1つの actor の中に閉じ込めて外とは ID だけをやり取りする。なお `BGContinuedProcessingTask` の launch handler 登録は「起動完了前に」の縛りから除外されている（SDK ヘッダに明記）ので、Infrastructure の中で最初の申告時に登録できる。

**GitHub の macOS ランナーでは Vision が返ってこず、テストプロセス全体が固まる。** GPU の無い VM 上のシミュレータで `VNRecognizeTextRequest` を実行すると完了せず、同期の `perform` が Swift 並行処理の協調スレッド（ランナーは数本）を全部塞ぐ。Policy のような一瞬で終わるテストまで 1 件も完了せず、6 時間の上限で打ち切られる（2026-09-10 / 09-11 の run）。**Vision を本物で回す 2 スイート（`VisionOCRServiceTests` / `StubPixelSourceServiceTests`）は CI では `-skip-testing` で外し、ローカルで回す。** macOS ジョブには `timeout-minutes` を付けて固まっても 30 分で落とす。

**Vision の文字認識はバックグラウンドで GPU を使えず止まる。compute device の指定では回避できない。** 背景では `IOGPUMetalError: Insufficient Permission (to submit GPU work from background)` になる。`setComputeDevice(_:for:)` で Neural Engine / CPU を選んでも、前処理が Metal を使うので同じ。UIKit の背景猶予（約30秒）が切れた瞬間に詰まり、進捗ゼロが45秒続くと dasd が `marking stalled` → BGContinuedProcessingTask を打ち切る。理由はアプリ側のログに出ない — **Console.app で `dasd` プロセスを見る**。正解は entitlement「Background GPU Access」+ `requiredResources = .gpu` だが、**個人の開発チームでは provisioning が拒否される**（有料プログラムが必要）。いまは `.gpu` を要求して拒否されたら継続しない。

**actor のメソッド内で作った普通のクロージャは「その actor に隔離」と推論される。OS のコールバックに渡すと実機で落ちる**（「Incorrect actor executor assumption; expected '...Service' executor」）。ObjC から来る `(BGTask) -> Void` や `expirationHandler: (() -> Void)?` は `@Sendable` が付いていないので、この推論が黙って働く。コンパイルは通り、OS が自分のキューから呼んだ瞬間に実行時チェックで落ちる。**OS に渡すクロージャには `@Sendable` を明示**し、actor に触るのは中で `Task { await self... }` を挟む。

