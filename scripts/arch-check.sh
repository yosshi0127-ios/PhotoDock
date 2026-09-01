#!/bin/bash
# アーキ規約の機械検査のうち、SwiftLint の custom_rules（単一ファイル regex）で表現できない項目。
# SwiftLint とセットで使う: swiftlint lint --strict --quiet && scripts/arch-check.sh
# exit 0 以外 = 違反あり。
set -u
cd "$(dirname "$0")/.." || exit 1

# アプリターゲットのルート（repo ルートからの相対）。プロジェクト固有名はここだけ。
APP="PhotoDock"
DI_DIR="$APP/App/DI"
status=0

# (1) DI の3値: 各 DependencyValues+*.swift に liveValue / previewValue / testValue が揃っているか（恒常ルール5）
for f in "$DI_DIR"/DependencyValues+*.swift; do
  for v in liveValue previewValue testValue; do
    if ! grep -q "$v" "$f"; then
      echo "error: $f: $v がない（DI は live/preview/test の3値必須）" >&2
      status=1
    fi
  done
done

# (2) 1依存1ファイル: DI ファイルごとに DependencyKey は1つだけ
for f in "$DI_DIR"/DependencyValues+*.swift; do
  count=$(grep -c ": DependencyKey" "$f")
  if [ "$count" -ne 1 ]; then
    echo "error: $f: DependencyKey が ${count}個（1依存1ファイル）" >&2
    status=1
  fi
done

# (3) 3点セットの欠け: Core の protocol が App/DI に登録されているか（恒常ルール5）
for name in $(grep -rhE "^protocol \w+" "$APP/Core/Services" "$APP/Core/Repositories" | sed -E 's/^protocol ([A-Za-z0-9_]+).*/\1/'); do
  if ! grep -rq "any $name" "$DI_DIR"; then
    echo "error: Core protocol '$name' が App/DI に未登録（Core protocol → Infra 実装 → DI 3値 の3点セット）" >&2
    status=1
  fi
done

# (4) liveValue の中身: 本番実装であること（Stub/Noop/Unimplemented を live に登録していないか）
#     liveValue はテストでも Preview でも踏まれないため、静的に見ないと事故に気づけない。
#     実行時側の担保は SwiftArchitectureSampleTests/LiveDependenciesSmokeTests.swift。
for f in "$DI_DIR"/DependencyValues+*.swift; do
  if grep -E "liveValue" "$f" | grep -qE "\b(Stub|Noop|Unimplemented|Mock|Fake|Dummy)"; then
    echo "error: $f: liveValue に Stub/Noop/Unimplemented 系を登録している（live は本番実装）" >&2
    status=1
  fi
done

if [ "$status" -eq 0 ]; then
  echo "arch-check: OK（DI 3値 / 1依存1ファイル / protocol 登録漏れなし / liveValue は本番実装）"
fi
exit $status
