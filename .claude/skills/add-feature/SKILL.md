---
name: add-feature
description: このプロジェクトに新しい機能・画面・サービス・リポジトリ・依存を追加するときに必ず使う。トリガー例:「◯◯機能を追加して」「◯◯画面を作って」「◯◯サービス/リポジトリを追加」「新しい依存を登録したい」。バグ修正・リネーム・コメント修正だけのときは使わない。
---

# 機能追加の定型手順

## When to Use
- 新しい画面 / 機能 / UseCase / サービス / リポジトリ / DI 登録を伴う変更

## When NOT to Use
- 既存コードのバグ修正・微修正（CLAUDE.md の恒常ルールだけ守ればよい）
- アーキテクチャの質問（→ `architecture-guide`）、レビュー（→ `review-architecture`）

## 手順（この順で。層を飛ばさない）

外部 I/O（カメラ・通信・永続化・OS 機能）が必要な場合は ①→⑦ すべて。
純粋ロジックの追加なら ④ から。既存依存だけで済む画面追加なら ⑤ から。

### ① Core に protocol（契約）

- 能力（〜する）→ `Core/Services/`、永続化 → `Core/Repositories/`
- **Foundation 以外 import 禁止。実装の隔離（@MainActor 等）を書かない**（隔離は実装側）
- I/O の意味論（バッファリング・失敗時の扱い）が重要なら doc コメントで契約として明記

```swift
import Foundation

/// <役割を1行>。実装は <想定技術>。
protocol FooService: Sendable {
    func doSomething(_ input: Bar) async throws -> Baz
}
```

### ② Infrastructure に実装

- 場所: `Infrastructure/{Imaging|Vision|Network|Persistence}/`（必要なら層内にディレクトリを足す）
- 命名: **具体技術プレフィックス + protocol 名**（例: `VisionOCRService`, `URLSessionBackendClient`, `InMemoryAnalysisRecordRepository`）。REST は通信手段の名前ではないので使わない
- UIKit 等で MainActor が必要なら **実装に** `@MainActor` を付け、`nonisolated init() {}` を足す（DependencyKey の static 初期化から生成されるため）

### ③ App/DI に登録（3値必須）

`App/DI/DependencyValues+<名前>.swift` を**1依存1ファイル**で新規作成:

```swift
import Dependencies

// <この依存の1行説明。preview に何を選んだ理由も>
private enum FooServiceKey: DependencyKey {
    static let liveValue: any FooService = URLSessionFooService()      // 本番
    static let previewValue: any FooService = StubFooService()          // Preview 安全（副作用ゼロ）
    static let testValue: any FooService = UnimplementedFooService()    // 上書き忘れ検知
}

extension DependencyValues {
    var foo: any FooService {
        get { self[FooServiceKey.self] } set { self[FooServiceKey.self] = newValue }
    }
}
```

- `previewValue` は副作用ゼロ、かつ**他の previewValue とセットで Preview の見た目が成立する値**にする（例: frameSource が1枚返す→ocr が制限語を返す→分類結果カードが見える）
- `testValue` は `Support/Mocks/UnimplementedServices.swift` に `Unimplemented<名前>` を追加（fatalError）
- Stub は `Support/Mocks/Stub<名前>.swift`

### ④ UseCase（Features/UseCases/）

- **具体 struct**（protocol にしない）。生の依存（`@Dependency`）を持てる**唯一の場所**
- 呼び口は `callAsFunction`
- 画面をまたいで共有する。lint の例外は `UseCases?/` というパスにアンカーしているので、この名前のディレクトリ以外に置くと落ちる

```swift
import Foundation
import Dependencies

/// <何をオーケストレーションするか1行>
struct DoSomethingUseCase: Sendable {
    @Dependency(\.foo) private var foo

    func callAsFunction(_ input: Bar) async throws -> Baz {
        try await foo.doSomething(input)
    }
}
```

### ⑤ State（Features/Screens/<画面>/）

- `@MainActor @Observable final class`。**UseCase だけを持つ**（`@Dependency` 禁止・import Dependencies 不要)

```swift
import Foundation
import Observation

@MainActor
@Observable
final class FooState {
    private(set) var result: Baz?
    private(set) var errorMessage: String?

    // 依存は UseCase 経由のみ（生サービス/リポジトリは State に持たない）
    private let doSomething = DoSomethingUseCase()

    init() {}
}
```

### ⑥ View（Features/Screens/<画面>/）

- 依存ノータッチ。`@State private var state = FooState()` で State を生成するだけ
- 色・フォントは `Support/Theme/`（`Color.warningAccent` 等）、直リテラル禁止

### ⑦ テスト（ユニットテストターゲット）

- 対象は **`withDependencies { } operation: { }` の中で生成**する（`@Dependency` は生成時点の context を捕捉するため）
- Spy は `TestDoubles.swift` に追加

```swift
@Test("<挙動を日本語で>")
func something() async throws {
    let spy = SpyFooService()
    try await withDependencies {
        $0.foo = spy
    } operation: {
        let useCase = DoSomethingUseCase()   // ← 必ずこの中で生成
        try await useCase(input)
    }
    #expect(spy.callCount == 1)
}
```

## 完了前チェックリスト

- [ ] State に `@Dependency` / import Dependencies がない（UseCase だけ）
- [ ] Core に Foundation 以外の import・`@MainActor` がない
- [ ] DI は3値揃っている（live / preview / test）。testValue は Unimplemented
- [ ] previewValue は副作用ゼロで、コメントの説明と実際の挙動が一致している
- [ ] 実装名は「具体技術 + protocol 名」
- [ ] テストは withDependencies の中で対象を生成している
- [ ] `xcodebuild test` が green（CLAUDE.md のコマンド）
