---
name: review-architecture
description: このリポジトリのアーキテクチャ・DI・層構造のレビューを求められたときに使う。トリガー例:「レビューして」「アーキ確認して」「層違反ないか見て」「依存関係チェックして」。SwiftUI の記述レベルだけを見たいときは swiftui-pro を直接使う。
---

# アーキテクチャレビュー手順

レビューは「1. 機械検査 → 2. 意味論チェック → 3. SwiftUI 記述（swiftui-pro 委譲）→ 4. 報告」の順で行う。

## 1. 機械検査（まず必ず実行する）

repo ルート（`.swiftlint.yml` がある場所）で以下2つを実行。**どちらかが exit 0 以外なら違反あり**。

```bash
swiftlint lint --strict --quiet   # 恒常ルール1〜4: import / @Dependency 位置 / 隔離漏れ / Policy 純粋性 / Features→Infra 具象参照
scripts/arch-check.sh             # 恒常ルール5: DI 3値 / 1依存1ファイル / Core protocol の登録漏れ
```

（編集時は PostToolUse hook でも SwiftLint が自動実行されるが、レビューでは全体を明示的に流す。
SwiftLint が無い環境では `.swiftlint.yml` の custom_rules と同等の grep を代替実行する）

## 2. 意味論チェック（grep では見えない違反）

- **隔離の漏れ**: 実装都合（UIKit の MainActor 等）が Core の契約に刻まれていないか。隔離は実装側、契約は async 要件のみ
- **previewValue の整合**: ①副作用ゼロか ②コメントの説明と実際の挙動が一致するか ③**セットとして Preview の物語が成立するか**（例: frameSource が入力を返さなければ ocr の「読み取りあり」は永遠に描画されない）
- **testValue の安全網**: Unimplemented（呼ばれたら気づける実装）か。live 実装を testValue に使っていないか
- **Policy の純粋性**: 分類（`Assessment` を返す）だけか。副作用・I/O・「high なら通知する」等の対応実行が混ざっていないか（対応は UseCase）
- **エンティティの表現力**: 複数の意味を Optional の nil 1つに畳み込んでいないか（例: `mediaURL: URL?` の nil が「なし」と「失敗」を兼ねる → enum で分離）
- **コメントと実装の一致**: 「◯◯を返す」と書いて別の値を返す等。コメントは書いた時点でなく現在の実装と照合する
- **stale ドキュメント**: README・CLAUDE.md のコード例が現行実装と一致しているか

## 3. SwiftUI 記述レベル（委譲）

View 層のコード（API の使い方・状態管理・パフォーマンス・アクセシビリティ）は、
**Skill ツールで `swiftui-pro` を発火**してレビューする。アーキ観点（本スキル）と記述観点（swiftui-pro）は両方報告に含める。

## 4. 報告形式

- 重大度順に:「`ファイル:行` / 違反内容 / 根拠（恒常ルール番号 or 理由）/ 修正方針」
- 機械検査が全て空なら「機械検査 5項目クリア」と明記した上で、意味論チェックの結果を報告
- `liveValue` に Stub/Noop/Unimplemented が登録されていないか（live は本番実装。静的検査は arch-check の (4)）
- 未実装の残し方: `liveValue` に fatalError を置かない。動く最小実装 + TODO か、明示的なエラー（`.notConfigured` 等）にする
