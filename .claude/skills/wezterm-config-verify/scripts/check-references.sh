#!/usr/bin/env bash
# 설정이 참조하는 외부 대상이 실제로 존재하는지 확인한다.
#
# 왜 필요한가: wezterm 은 존재하지 않는 WSL 배포판이나 실행 파일을 가리켜도 설정 로드 단계에서는
# 아무 오류를 내지 않는다. 해당 도메인을 열거나 단축키를 누르는 순간에야 조용히 실패한다.
# 실제로 wsl_domains 가 'Ubuntu-22.04' 를 가리키는데 설치된 이름은 'Ubuntu' 라서
# Ctrl+Alt+T 단축키와 launch_menu 항목이 동작하지 않고 있었다 (2026-09-03).
#
# 사용법: bash .claude/skills/wezterm-config-verify/scripts/check-references.sh [repo_root]
# 종료 코드: 0 = 문제 없음, 1 = 존재하지 않는 대상을 참조

set -u
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
cd "$ROOT" || exit 1

status=0

# --- WSL 배포판 ---
if command -v wsl >/dev/null 2>&1; then
   installed=$(wsl -l -q 2>/dev/null | tr -d '\000\r')
   refs=$(sed -nE "s/.*distribution = '([^']+)'.*/\1/p" config/domains.lua | sort -u)
   for d in $refs; do
      if echo "$installed" | grep -qx "$d"; then
         echo "OK    WSL 배포판 '$d' 존재"
      else
         echo "실패  WSL 배포판 '$d' 없음 — 설치된 목록: $(echo $installed | tr '\n' ' ')"
         status=1
      fi
   done
   [ -z "$refs" ] && echo "정보  config/domains.lua 에 wsl 배포판 참조 없음"
else
   echo "SKIP  wsl 미설치"
fi

# --- launch_menu / default_prog 가 부르는 실행 파일 ---
# args 배열의 첫 요소만 본다. 절대경로(mac/linux 분기)는 이 플랫폼 대상이 아니므로 건너뛴다.
# 주석 처리된 항목(-- 로 시작)은 제외한다.
progs=$(grep -v '^\s*--' config/launch.lua | sed -nE "s/.*args = \{ '([^']+)'.*/\1/p" | sort -u)
missing=""
# Windows 절대경로(C:\...)는 Lua 문자열이라 백슬래시가 이스케이프돼 있다.
# 되돌린 뒤 파일 존재로 판정한다. POSIX 절대경로는 다른 OS 분기이므로 건너뛴다.
while IFS= read -r p; do
   [ -z "$p" ] && continue
   case "$p" in
      /*) continue ;;
      [A-Za-z]:*)
         real=$(printf '%s' "$p" | sed 's/\\\\/\\/g; s|\\|/|g')
         [ -f "$real" ] || missing="$missing $p"
         ;;
      *)
         command -v "$p" >/dev/null 2>&1 || missing="$missing $p"
         ;;
   esac
done <<EOF
$progs
EOF
if [ -n "$missing" ]; then
   echo "정보  launch_menu 에 이 머신에 없는 프로그램:$missing (다른 OS 분기이거나 미설치)"
else
   echo "OK    launch_menu 프로그램 모두 존재"
fi

exit $status
