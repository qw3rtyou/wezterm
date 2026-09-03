#!/usr/bin/env bash
# config/ 모듈 간 최상위 옵션 키 중복 검사.
#
# 왜 정적 검사인가: config/init.lua 의 Config:append 는 중복 키를 덮어쓰지 않고
# wezterm.log_warn 한 줄만 남긴 뒤 건너뛴다. 그런데 이 경고는 설정이 정상 로드될 때
# `wezterm ls-fonts` 의 stdout/stderr 어디에도 나타나지 않는다 (GUI 디버그 오버레이로만 간다).
# 즉 런타임 관찰로는 잡을 수 없어 소스에서 직접 찾아야 한다.
#
# 사용법: bash .claude/skills/wezterm-config-verify/scripts/check-duplicate-keys.sh [repo_root]
# 종료 코드: 0 = 중복 없음, 1 = 중복 발견

set -u
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
cd "$ROOT" || exit 1

# 최상위 키 = 들여쓰기 정확히 3칸 (.stylua.toml indent_width = 3).
# 중첩 테이블 키는 6칸 이상이므로 걸리지 않는다.
# config/init.lua 는 Config 클래스 정의라 옵션 원천이 아니므로 제외한다.
tmp=$(mktemp)
for f in config/*.lua; do
   case "$f" in */init.lua) continue ;; esac
   {
      sed -nE 's/^   ([A-Za-z_][A-Za-z0-9_]*) *=.*/\1/p' "$f"
      sed -nE 's/^options\.([A-Za-z_][A-Za-z0-9_]*) *=.*/\1/p' "$f"
   } | sort -u | while read -r k; do
      [ -n "$k" ] && printf '%s\t%s\n' "$k" "$f"
   done >> "$tmp"
done

dupes=$(cut -f1 "$tmp" | sort | uniq -d)

if [ -z "$dupes" ]; then
   echo "중복 없음 — config/ 모듈 간 최상위 옵션 키 충돌 없음"
   rm -f "$tmp"
   exit 0
fi

echo "중복 옵션 키 발견 — wezterm.lua 의 :append() 순서상 먼저 오는 모듈이 이기고, 나머지는 조용히 무시된다:"
echo
for k in $dupes; do
   printf '  %s\n' "$k"
   awk -F'\t' -v key="$k" '$1 == key { print "      " $2 }' "$tmp"
done
echo
echo "wezterm.lua 의 append 순서: appearance → bindings → domains → fonts → general → launch"
rm -f "$tmp"
exit 1
