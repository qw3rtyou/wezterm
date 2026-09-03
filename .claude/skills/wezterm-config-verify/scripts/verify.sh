#!/usr/bin/env bash
# WezTerm 설정 4단 검증: 포맷 / 린트 / 실제 로드 / 중복 옵션 키
# 사용법: bash .claude/skills/wezterm-config-verify/scripts/verify.sh [repo_root]
# 종료 코드: 0 = 수행된 모든 검사 통과, 1 = 하나 이상 실패
# 미설치 도구는 SKIP 으로 보고하며 실패로 치지 않는다 (통과와 명확히 구분).

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$(cd "$HERE/../../../.." && pwd)}"
cd "$ROOT" || { echo "FAIL: cannot cd to $ROOT"; exit 1; }

# wezterm 의 --config-file 은 "진입 파일"만 바꾼다. require('config.*') 등 모듈은 여전히
# 표준 설정 디렉토리(~/.config/wezterm)에서 해석된다 — 실측 확인됨.
# 주의: WEZTERM_CONFIG_DIR 라는 환경변수는 존재하지 않는다(설정해도 무시됨).
# WEZTERM_CONFIG_FILE 은 동작하지만 진입 파일만 바꿀 뿐 모듈 해석 경로는 그대로다.
# 따라서 레포 사본에 대해서는 로드 검사가 의미를 갖지 못한다. 라이브 설정 디렉토리일 때만 수행한다.
CONFIG_DIR="$HOME/.config/wezterm"
ROOT_ABS="$(pwd)"
CONFIG_ABS="$(cd "$CONFIG_DIR" 2>/dev/null && pwd || echo '')"

status=0
printf '%-10s | %-6s | %s\n' "검사" "상태" "상세"
printf -- '-----------|--------|------------------------------------------\n'
report() { printf '%-10s | %-6s | %s\n' "$1" "$2" "$3"; }

# --- stylua 위치 해석 --------------------------------------------------------
# winget 은 실행 파일을 PATH 에 추가하지만 이미 열려 있던 셸에는 반영되지 않는다.
# PATH 에 없으면 winget 패키지 디렉토리에서 직접 찾는다.
STYLUA=""
if command -v stylua >/dev/null 2>&1; then
   STYLUA="stylua"
else
   cand=$(find "$LOCALAPPDATA/Microsoft/WinGet/Packages" -maxdepth 2 -iname 'stylua.exe' 2>/dev/null | head -1)
   [ -n "$cand" ] && STYLUA="$cand"
fi

# 1. 포맷
#    로컬 호출이 CI 와 다른 이유 (모두 실측 확인):
#    a) 작업 트리가 CRLF(core.autocrlf=true)인데 .stylua.toml 은 line_endings="Unix" 라,
#       보정 없이 돌리면 모든 파일이 통째로 diff 로 잡힌다. git 이 커밋 시 LF 로 정규화하므로
#       로컬에서는 --line-endings Windows 로 맞춰야 내용 차이만 보인다.
#    b) stylua 2.x 는 Lua 5.2 의 goto/::label:: 문법을 기본으로 파싱하지 못한다.
#       config/init.lua 와 utils/opts-validator.lua 가 여기 걸리므로 제외한다.
#    c) CI 의 -g '!/config/init.lua' 는 선행 슬래시 때문에 실제로 아무것도 제외하지 못한다.
#       제외가 동작하는 형태는 '!**/init.lua' 다.
if [ -n "$STYLUA" ]; then
   LE_ARG=""
   # 주의: $(head -1 file) 은 MSYS 가 CRLF 를 번역해 버려 \r 검출에 쓸 수 없다. od 로 본다.
   if head -c 400 wezterm.lua 2>/dev/null | od -An -c | grep -q '\\r'; then
      LE_ARG="--line-endings Windows"
   fi
   if out=$("$STYLUA" $LE_ARG -g '!**/init.lua' -g '!**/opts-validator.lua' \
               --check wezterm.lua colors/ config/ events/ utils/ 2>&1); then
      report "stylua" "통과" "포맷 차이 없음 (goto 라벨 파일 2개 제외)"
   else
      files=$(echo "$out" | grep '^Diff in' | sed 's/^Diff in //;s/:$//' | tr '\n' ' ')
      report "stylua" "실패" "${files:-포맷 차이 있음}"
      echo "$out" | sed 's/^/    /'
      status=1
   fi
else
   report "stylua" "SKIP" "미설치 — winget install JohnnyMorganz.StyLua"
fi

# 2. 린트 — CI와 동일한 대상. luacheck 가 PATH 에 없으면 CI 가 쓰는 바로 그 도커
#    이미지로 대신 돌린다. 로컬에 Lua 툴체인을 깔지 않고도 CI 와 동일한 결과를 얻는다.
#    (이 검사를 SKIP 으로 넘겼다가 CI 에서 W211/W611 로 실패한 적이 있다 — 2026-09-03)
LUACHECK_ARGS="wezterm.lua colors/* config/* events/* utils/*"
LUACHECK_IMAGE="ghcr.io/lunarmodules/luacheck:v1.2.0"

if command -v luacheck >/dev/null 2>&1; then
   lint_out=$(luacheck $LUACHECK_ARGS 2>&1); lint_rc=$?; lint_how="로컬"
elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
   lint_out=$(MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W 2>/dev/null || pwd):/w" \
      --workdir /w --entrypoint sh "$LUACHECK_IMAGE" \
      -c "luacheck $LUACHECK_ARGS" 2>&1); lint_rc=$?; lint_how="docker(CI 동일 이미지)"
else
   lint_rc=-1
fi

if [ "$lint_rc" -eq -1 ]; then
   report "luacheck" "SKIP" "미설치 + docker 없음"
elif [ "$lint_rc" -eq 0 ]; then
   report "luacheck" "통과" "$lint_how — $(echo "$lint_out" | tail -1 | sed 's/\x1b\[[0-9;]*m//g')"
else
   report "luacheck" "실패" "$lint_how — $(echo "$lint_out" | tail -1 | sed 's/\x1b\[[0-9;]*m//g')"
   echo "$lint_out" | sed 's/\x1b\[[0-9;]*m//g' | grep -E "^\s+\S+:[0-9]+:[0-9]+:" | sed 's/^/    /'
   status=1
fi

# 3. 실제 로드 — wezterm 은 설정 오류에도 종료 코드 0 을 반환하므로 stderr 를 봐야 한다.
#    --config-file 은 쓰지 않는다: 상대경로를 주면 wezterm.config_dir 가 어긋나
#    backdrops:set_images() 의 glob 이 0장을 반환해 가짜 background.source 에러가 뜬다.
#    나란히 설치한 nightly 가 있으면 그쪽도 함께 본다 — 사용자가 실제로 띄우는 바이너리가
#    PATH 의 stable 이 아닐 수 있고, 두 빌드는 설정 수용 범위가 다르다.
NIGHTLY="$LOCALAPPDATA/Programs/WezTerm-nightly/wezterm.exe"
wt_bins=""
command -v wezterm >/dev/null 2>&1 && wt_bins="wezterm"
[ -x "$NIGHTLY" ] && wt_bins="$wt_bins $NIGHTLY"

if [ -z "$wt_bins" ]; then
   report "wezterm" "SKIP" "미설치"
elif [ -z "$CONFIG_ABS" ] || [ "$ROOT_ABS" != "$CONFIG_ABS" ]; then
   report "wezterm" "SKIP" "사본은 검증 불가 — 모듈이 $CONFIG_DIR 에서 해석됨"
else
   wt_fail=0
   wt_detail=""
   for bin in $wt_bins; do
      ver=$("$bin" --version 2>/dev/null | awk '{print $2}')
      out=$("$bin" ls-fonts 2>&1)
      errs=$(echo "$out" | grep -i 'ERROR' || true)
      if [ -n "$errs" ]; then
         wt_fail=1
         wt_detail="$wt_detail ${ver:-?}=실패"
         echo "    [${ver:-$bin}]" 
         echo "$errs" | sed 's/^/      /'
      else
         wt_detail="$wt_detail ${ver:-?}=통과"
      fi
   done
   if [ "$wt_fail" -eq 1 ]; then
      report "wezterm" "실패" "$wt_detail"
      status=1
   else
      report "wezterm" "통과" "$wt_detail"
   fi
fi

# 4. 중복 옵션 키 — Config:append 가 조용히 건너뛰는 사각지대.
#    이 경고는 정상 로드 시 wezterm 출력에 나타나지 않으므로 정적 검사로 잡는다.
if dup_out=$(bash "$HERE/check-duplicate-keys.sh" "$ROOT" 2>&1); then
   report "중복키" "통과" "config/ 모듈 간 옵션 키 충돌 없음"
else
   report "중복키" "실패" "옵션이 조용히 무시되고 있음"
   echo "$dup_out" | sed 's/^/    /'
   status=1
fi

# 5. 참조 대상 실재 — 설정이 없는 WSL 배포판/실행 파일을 가리켜도 wezterm 은 로드 시
#    아무 말도 하지 않고, 해당 도메인을 열 때에야 조용히 실패한다.
if ref_out=$(bash "$HERE/check-references.sh" "$ROOT" 2>&1); then
   report "참조" "통과" "$(echo "$ref_out" | grep -c '^OK') 건 확인, 없는 대상 없음"
   echo "$ref_out" | grep '^정보' | sed 's/^/    /'
else
   report "참조" "실패" "존재하지 않는 대상을 참조 중"
   echo "$ref_out" | sed 's/^/    /'
   status=1
fi

exit $status
