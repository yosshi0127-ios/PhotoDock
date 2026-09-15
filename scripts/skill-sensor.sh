#!/bin/bash
# UserPromptSubmit フック: ユーザーの入力に CLAUDE.md「スキルカタログ」のトリガー語が含まれていて、
# 該当スキルがこの文脈（直近の compaction 以降）で Skill ツール経由で読まれていなければ、
# 注意を additionalContext として文脈に注入する。強制はしない（誤検知しても害が小さい側に倒す）。
#
# 入力: stdin に JSON（prompt, transcript_path）。出力: 注意があるときだけ JSON。無ければ何も出さず exit 0。
# トランスクリプトは JSONL。Skill の呼び出しは assistant エントリの tool_use（name=Skill, input.skill）に残る。
# compaction 後は読んだスキルの本文が文脈から消えるので、isCompactSummary の行より後だけを見る。
#
# 元ネタは Android 研修プロジェクトの check_skill_loaded.sh。
set -u
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -z "$prompt" ] && exit 0

# トリガー語 → スキル（CLAUDE.md のスキルカタログと同じ対応。育てる運用）
required=""
add() { case " $required " in *" $1 "*) ;; *) required="$required $1" ;; esac; }

grep -qE '(機能|画面|サービス|リポジトリ|依存|UseCase|ユースケース).{0,12}(追加|作成|作って|作りたい|登録|新設|足し|増や)' <<<"$prompt" && add add-feature
grep -qE 'レビュー|アーキ.{0,6}(確認|見て|チェック)|層違反|依存関係.{0,6}(チェック|確認)' <<<"$prompt" && add review-architecture
grep -qiE '検証|動作確認|テスト.{0,6}(回|流|実行|走)|コミット|commit' <<<"$prompt" && add verify
grep -qE 'どこに置|置き場|何を入れ|なぜ.{0,10}(設計|protocol|struct|UseCase)|Policy.{0,4}(って|とは)|AppState' <<<"$prompt" && add architecture-guide
grep -qiE 'SwiftUI|View([^A-Za-z]|$)|Preview|modifier|モディファイア|アニメーション|レイアウト|セル|グリッド|タップ|ボタン|ツールバー|toolbar|画面' <<<"$prompt" && add swiftui-pro

[ -z "$required" ] && exit 0

# この文脈で読み込み済みのスキル（直近の compaction 以降）。プラグインの接頭辞（xxx:）は落として比べる
invoked=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  cut=$(grep -nF '"isCompactSummary":true' "$transcript" | tail -1 | cut -d: -f1)
  invoked=$(tail -n +"$(( ${cut:-0} + 1 ))" "$transcript" | grep -F '"name":"Skill"' \
    | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Skill") | .input.skill // empty' 2>/dev/null \
    | sed -E 's/^.*://' | sort -u)
fi

missing=""
for skill in $required; do
  grep -qx "$skill" <<<"$invoked" || missing="$missing $skill"
done
[ -z "$missing" ] && exit 0

msg="[skill-sensor] 入力に CLAUDE.md スキルカタログのトリガー語があります。該当スキルはこの文脈でまだ読まれていません（compaction 後は読み直しが要る）。応答の前に Skill ツールで読んでください:$missing"
jq -n --arg msg "$msg" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $msg}}'
exit 0
