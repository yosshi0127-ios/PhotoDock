# PhotoDock / 写真ドック

カメラロールの棚卸し診断 iOS アプリ（全量スキャンで「見られたらまずい写真」を洗い出し、対処まで導く）。**クリーン3層 + swift-dependencies DI**
（アーキテクチャは https://github.com/yosshi0127-ios/SwiftArchitectureSample に基づく。規約の詳細はスキル `architecture-guide`）。
**プロダクトの方針・決定事項・制約は `docs/product-brief.md` が原本**。作業前に必ず読む。

## 恒常ルール（違反する変更は入れない）

1. 生の依存（`@Dependency`）を持てるのは **UseCase だけ**
2. State は **UseCase 経由のみ**（生サービス/リポジトリ禁止）。View / RootView は依存ノータッチ
3. `Core/` は **Foundation 以外 import 禁止**（SwiftUI / Dependencies / Infrastructure 不可）。実装の隔離（`@MainActor` 等）を Core の protocol に書かない
4. **分類は Policy、対応の実行は UseCase**（Policy に副作用・I/O を書かない）
5. 依存の追加は3点セット:「Core protocol → Infrastructure 実装 → `App/DI/DependencyValues+<名前>.swift`（liveValue / previewValue / testValue の3値）」
   - `liveValue` には本番実装だけを登録する（Stub / Noop / Unimplemented を live に置かない）

## ビルド / テスト

```bash
xcodebuild build -scheme PhotoDock -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'
xcodebuild test  -scheme PhotoDock -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'
```

- **Xcode プロジェクトは未作成**。最初の作業は Xcode での新規プロジェクト生成（App / Swift 6 / iOS 18、repo ルート直下に `PhotoDock.xcodeproj`、bundle ID `com.yosshi0127.photodock`）と swift-dependencies の SPM 追加。生成後にこの節の destination を実環境に合わせて更新する
- 初回ビルドは2分超かかることがある（バックグラウンド実行推奨）
- SourceKit の diagnostics（`No such module 'Dependencies'` 等）はインデックス誤検知が多い。真実は xcodebuild の結果
- **Vision の顔検出はシミュレータで動かない**（`Could not create inference context` / code 9）。環境依存の検出器は「検出ゼロで続行」に設計する（brief 参照）

## アーキ規約の機械検査

- 恒常ルール1〜4（+ Features→Infra 具象参照）: `.swiftlint.yml` の custom_rules（スタイルルールは無効）
  - `no_infra_in_features` の具象名リストは Infrastructure 実装を追加するたびに育てる
- 恒常ルール5（DI 3値・1依存1ファイル・登録漏れ・liveValue が本番実装）: `scripts/arch-check.sh`

Swift ファイル編集時は PostToolUse hook で SwiftLint が自動実行される。全体検査は repo ルートで:

```bash
swiftlint lint --strict --quiet && scripts/arch-check.sh   # exit 0 以外 = 違反あり
```

同じ2つ + テストは CI（`.github/workflows/ci.yml`）でも回る。

## GitHub

- リポジトリは個人アカウント **yosshi0127-ios**（private）に作る。会社アカウントと混在する端末なので、
  git identity は `--local` で `yosshi0127-ios <105440671+yosshi0127-ios@users.noreply.github.com>` を設定済み・
  credential も このリポジトリだけ `!gh auth git-credential` を使う設定済み（コピー元と同じ構成）
- push 前に `gh auth status` で active が yosshi0127-ios であることを確認する

## スキルカタログ（該当する話題では必ず Skill ツールで発火する）

| 話題・トリガー | 使うスキル |
|---|---|
| 機能・画面・サービス・依存を「追加/作成」する | `add-feature` |
| アーキテクチャ / DI / 層構造を「レビュー」する | `review-architecture`（SwiftUI 記述レベルは `swiftui-pro` を併用） |
| 変更を「検証」する・コミット前チェック | `verify`（lint → arch-check → テスト → UI 変更時は Preview 描画確認） |
| 「どこに置く？」「何を入れていい？」「なぜこの設計？」 | `architecture-guide` |
| SwiftUI の書き方・API・モダン化・パフォーマンス | `swiftui-pro`（プラグイン） |
