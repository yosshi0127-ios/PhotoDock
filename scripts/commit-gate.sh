#!/bin/bash
# コミット前ゲート（PreToolUse / matcher: Bash）。git commit を含むコマンドのとき、
#   1) Swift を変更しているのに、最後の Swift 編集より後に `verify` スキルを読んでいない
#   2) View を変更しているのに、最後の View 編集より後に `swiftui-pro` スキルを読んでいない
# なら exit 2 で止め、理由を stderr に出す（CLAUDE.md のスキルカタログ / review-architecture の工程3）。
#
# 「読んだか」はトランスクリプト（JSONL）の Skill ツール呼び出しで判定する。Edit/Write/MultiEdit の
# tool_use と Skill の tool_use を出現順に並べ、最後の該当編集より後に Skill があれば通す
# （編集 → スキルの手順を踏む → コミット、の順を機械で見る）。
# Bash 経由（perl/sed）の編集は tool_use に残らないので、その場合はセッション内に呼び出しがあれば通す。
#
# 抜け道: コマンドに GATE_SKIP=1 を含めれば通す（トランスクリプトが読めない等の非常用）。
# permissionDecision: "ask" を返す方式は許可モードによって効かないので、exit 2 で止める。
set -u
root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$root" || exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
invoked=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)

# git commit を含まないコマンドには何もしない（git add -A && git commit ... の複合形も拾う）
case "$invoked" in *"git commit"*) ;; *) exit 0 ;; esac
case "$invoked" in *"GATE_SKIP=1"*) exit 0 ;; esac

# View の判定: Screens 配下の State 以外、RootView、および *View.swift
view_re='(/Features/Screens/[^/]+/[^/]*\.swift|/App/RootView\.swift|View\.swift)$'
view_exclude='State\.swift$'

changed=$({ git diff --name-only; git diff --cached --name-only; } 2>/dev/null | sort -u)
swift_changed=$(grep -E '\.swift$' <<<"$changed")
view_changed=$(grep -E "$view_re" <<<"$changed" | grep -vE "$view_exclude")
[ -z "$swift_changed" ] && exit 0

# トランスクリプトから「編集」と「Skill 読み込み」を出現順に取り出す（name TAB path TAB skill）
events=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  events=$(grep -E '"name":"(Skill|Edit|Write|MultiEdit)"' "$transcript" \
    | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use")
             | select(.name=="Skill" or .name=="Edit" or .name=="Write" or .name=="MultiEdit")
             | "\(.name)\t\(.input.file_path // "")\t\(.input.skill // "")"' 2>/dev/null)
fi

# $1: 編集対象の正規表現  $2: 除外の正規表現（空可）  $3: スキル名 → 最後の編集より後にスキルがあれば 0
passes() {
  awk -F'\t' -v re="$1" -v ex="$2" -v skill="$3" '
    $1 != "Skill" && $2 ~ re && (ex == "" || $2 !~ ex) { lastEdit = NR }
    $1 == "Skill" && $3 ~ ("(^|:)" skill "$")          { lastSkill = NR }
    END { exit !(lastSkill > lastEdit) }
  ' <<<"$events"
}

problems=""
if ! passes '\.swift$' '' verify; then
  problems="$problems
- Swift を変更していますが、最後の編集より後に verify スキルを読んでいません（lint → arch-check → テスト → UI 変更時は Preview）。"
fi
if [ -n "$view_changed" ] && ! passes "$view_re" "$view_exclude" swiftui-pro; then
  problems="$problems
- View を変更していますが、最後の View 編集より後に swiftui-pro スキルでレビューしていません:
$(printf '    %s\n' $view_changed)"
fi
[ -z "$problems" ] && exit 0

{
  echo "コミット前ゲート: 手順が抜けています。$problems"
  echo
  echo "Skill ツールで該当スキルを読み、その手順を踏んでから git commit をやり直してください。"
  echo "非常用（トランスクリプトが読めない等）: コマンドに GATE_SKIP=1 を付けると通ります。"
} >&2
exit 2
