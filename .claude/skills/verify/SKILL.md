---
name: verify
description: 変更後の検証・コミット前チェックを求められたときに使う。トリガー例:「検証して」「動作確認して」「テスト回して」「コミット前に確認」。lint → アーキ検査 → テスト →（UI 変更時）Preview 描画確認まで一気通貫で行う。レビュー（指摘出し）は review-architecture を使う。
---

# 変更検証手順

この順で実行する。**途中で失敗したら、以降に進む前にその出力ごと報告する。**

## 1. 機械検査（数秒）

repo ルートで:

```bash
swiftlint lint --strict --quiet && scripts/arch-check.sh
```

## 2. ビルド & テスト（初回2分超・バックグラウンド実行推奨）

**CLAUDE.md「ビルド / テスト」記載の `xcodebuild test` コマンドを実行する**（scheme / destination の真実の源は CLAUDE.md。ここに重複記載しない）。

- SourceKit の diagnostics（`No such module 'Dependencies'` 等）はインデックス誤検知が多い。**真実は xcodebuild の結果**
- Xcode MCP が使える場合は `BuildProject` / `RunAllTests` でも可（失敗時は `GetBuildLog` でログを取る）

## 3. UI に触れる変更のみ: Preview 描画確認

Xcode MCP の `RenderPreview` で該当 View の `#Preview` を画像化して目視確認する。

- **previewValue のセットで「物語」が成立しているか**（frameSource が1枚返す → ocr が制限語を返す → 分類結果カードが見える）
- 文字列がユーザー向け表記になっているか（enum のデバッグ表記の漏出はここで気づける）
- 色・フォントが `Support/Theme/` のセマンティック定義経由か

## 4. 報告

- **全ステップ通ったときだけ green と言う**。部分的成功を「ほぼOK」と丸めない
- テストを追加・変更した場合は、対象を `withDependencies { } operation: { }` の中で生成しているかも確認して一言添える
