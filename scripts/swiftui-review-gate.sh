#!/bin/bash
# SwiftUI の View を変更したままコミットしようとしたら止めて、swiftui-pro のレビューを促す。
#
# Claude Code の PreToolUse フック（matcher: Bash）から呼ばれ、stdin にツール入力の JSON を受け取る。
# 「git commit を含むコマンド」かつ「View が変更されている」ときだけ exit 2 で止める。
#
# permissionDecision: "ask" を返す方式は、このセッションの許可モードでは効かなかったため採らない
# （フックは発火し JSON も出力されるが、プロンプトが出ない）。exit 2 なら許可モードに依存しない。
#
# 抜け道: コマンドに SWIFTUI_REVIEWED=1 を含めれば通る。レビュー後の再コミットで
# 同じ判定に当たって進めなくなるのを避けるため（フックはレビュー済みかを知り得ない）。
#
# CLAUDE.md のスキルカタログ / review-architecture の工程3 に対応。
set -u

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$root" || exit 0

command -v jq >/dev/null 2>&1 || exit 0

invoked=$(cat | jq -r '.tool_input.command // ""' 2>/dev/null)

# git commit を含まないコマンドには何もしない（git add -A && git commit ... の複合形も拾う）
case "$invoked" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# レビュー済みの申告があれば通す
case "$invoked" in
  *"SWIFTUI_REVIEWED=1"*) exit 0 ;;
esac

# 変更中の View（staged / unstaged の両方を見る）
changed=$(
  {
    git diff --name-only
    git diff --cached --name-only
  } 2>/dev/null | sort -u | grep -E '(/View/[^/]*\.swift|View\.swift)$'
)

[ -z "$changed" ] && exit 0

{
  echo "SwiftUI の View を変更しています:"
  printf '  %s\n' $changed
  echo
  echo "コミット前に Skill ツールで swiftui-pro を発火してレビューしてください"
  echo "（CLAUDE.md のスキルカタログ / review-architecture の工程3）。"
  echo
  echo "レビュー済みなら、コマンドの先頭に SWIFTUI_REVIEWED=1 を付けて再実行してください。"
} >&2

exit 2
