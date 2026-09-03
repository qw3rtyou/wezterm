---
name: wezterm-config-edit
description: "WezTerm Lua 설정의 옵션·키바인딩·이벤트·플랫폼 분기를 안전하게 편집한다. config/ events/ utils/ 하위 Lua 파일 수정, 새 옵션 추가, 키바인딩 변경·추가, key_tables 편집, 상태바/탭 이벤트 핸들러 수정, win/mac/linux 분기 처리, SSH 도메인·launch_menu 항목 추가 시 반드시 이 스킬을 사용할 것. 설정 수정 재실행, 이전 변경 보완, 특정 모듈만 다시 수정 요청에도 사용."
---

# WezTerm Config Edit — 설정 모듈 편집

이 레포의 구조와 함정을 전제로 WezTerm 설정을 편집한다.

## 구조

```
wezterm.lua              진입점. backdrops 초기화 → 이벤트 setup → Config:append 체인
config/init.lua          Config 클래스. append 로 옵션 병합
config/{appearance,bindings,domains,fonts,general,launch}.lua
events/{left-status,right-status,tab-title,new-tab-button}.lua
utils/{platform,backdrops,cells,gpu-adapter,math,opts-validator}.lua
colors/custom.lua        색상 단일 출처
```

`wezterm.lua`의 append 순서: **appearance → bindings → domains → fonts → general → launch**

## 함정 1 — `Config:append`는 중복 키를 조용히 건너뛴다

`config/init.lua`의 `append`는 이미 존재하는 키를 만나면 `wezterm.log_warn`을 남기고 `goto continue`로 **무시한다.** 덮어쓰지 않는다.

```lua
if self.options[k] ~= nil then
   wezterm.log_warn('Duplicate config option detected: ', { old = ..., new = ... })
   goto continue
end
```

결과: `config/general.lua`에 `font_size`를 추가해도 `config/fonts.lua`가 먼저 append되므로 조용히 무시된다. 에러는 나지 않고, **이 경고는 정상 로드 시 `wezterm` 출력 어디에도 나타나지 않는다**(실측 확인). 런타임으로는 알 수 없으므로 `wezterm-config-verify`의 중복키 정적 검사에 의존해야 한다.

**새 옵션을 추가하기 전에 항상 먼저 확인하라:**

```bash
grep -rn '옵션명' config/
```

이미 있다면 새로 추가하지 말고 **정의된 그 모듈에서** 값을 고쳐라.

## 함정 2 — `set_images()`는 `wezterm.lua`에서만 호출한다

`utils/backdrops.lua`의 `set_images()`는 `wezterm.glob`을 쓰고, glob은 자식 프로세스를 띄운다. 초기 설정 로드 중 `wezterm.lua` 밖에서 호출하면 coroutine 에러가 난다. 해당 함수 주석에 명시돼 있으니 위치를 옮기지 마라.

## 함정 3 — 도메인 변경은 리로드로 반영되지 않는다

`automatically_reload_config = true`라 대부분의 옵션은 저장 즉시 반영되지만, **도메인 정의는
예외다.** `ssh_domains` 와 `wsl_domains` 모두 해당한다(둘 다 실측 확인). 도메인은 시작 시에만 등록되므로 `config/domains.lua`의 `default_prog`, `ssh_option`,
`remote_address` 등을 바꿔도 실행 중인 wezterm은 옛 정의로 접속한다. wezterm 업스트림의 오래된
미해결 이슈다 (#1279, #4284, #6650, #7072).

실측: `default_prog`를 바꾼 뒤 `wezterm cli spawn --domain-name kali-local`로 새 pane을 띄워도
이전 명령이 실행됐다. **wezterm을 완전히 재시작해야 적용된다.**

그래서 도메인을 고친 뒤에는:
1. 설정이 문법적으로 맞는지 `wezterm-config-verify`로 확인하고
2. 사용자에게 **재시작이 필요하다는 사실을 명시**하라 — 재시작 전 테스트 결과는 옛 정의를 본 것이라
   "적용 안 됨"으로 오판하기 쉽다
3. 급하면 실행 중인 세션에 같은 효과를 직접 적용해 임시로 메워라

## 함정 3 — `-- stylua: ignore`를 지우지 마라

`config/bindings.lua`의 `keys` 테이블 바로 위에 있다. 이 주석이 열 정렬을 보존한다. 지우면 stylua가 테이블을 재배치해 diff가 거대해지고 가독성이 무너진다.

**실행 중인 wezterm 이 실제로 가진 도메인 목록을 보는 법:** 없는 이름으로 spawn 을 시도하면
오류 메시지가 유효한 이름을 전부 나열한다. 설정 파일과 대조해 재시작이 필요한 상태인지 즉시 알 수 있다.

```bash
wezterm cli spawn --domain-name __nope__
# Error: ... Possible names are "kali-local", "WSL:Ubuntu-22.04", "local", ...
```

## 함정 4 — 문자 키 바인딩은 한글 입력 모드에서 매칭되지 않는다

`key = 'w'` 처럼 **문자**로 잡으면 한글 입력 상태에서 W 를 눌렀을 때 들어오는 문자가 달라
바인딩이 걸리지 않는다. `key = 'phys:W'` 는 자판 **위치**로 매칭하므로 입력 모드·자판 배열과
무관하게 동작한다. 이 레포의 알파벳 바인딩 30개는 모두 `phys:` 로 변환돼 있으니, 새 바인딩을
추가할 때도 알파벳이면 `phys:` 를 써라.

`wezterm show-keys` 출력에 `W (Physical)` 로 찍히면 제대로 적용된 것이다.

## 편집 규칙

**경계:** 이 스킬은 *구조와 동작*을 다룬다 — 옵션 스키마, 모듈 배치, 키바인딩, 플랫폼 분기, 이벤트 로직. *보이는 것*(색상, 배경 이미지, 커서 모양, 탭·상태바 렌더링)은 `wezterm-appearance` 스킬 소관이다. `config/appearance.lua`는 두 스킬이 공유하는 파일이므로 수정 전 어느 쪽 변경인지 먼저 정하라.


| 대상 | 파일 | 비고 |
|------|------|------|
| 창 동작·탭바 구조 옵션 | `config/appearance.lua` | `enable_tab_bar`, `tab_max_width`, `window_padding` 등 **구조** 옵션만. 색상·커서 모양·탭 렌더링 등 **시각** 요소는 `wezterm-appearance` 스킬 소관 |
| 키바인딩 | `config/bindings.lua` | `mod.SUPER`(mac=SUPER, win/linux=ALT) 사용 |
| SSH 도메인 | `config/domains.lua` | `ssh_option.port`는 **문자열**이어야 한다 |
| 실행 메뉴·기본 셸 | `config/launch.lua` | 플랫폼별 분기 필수 |
| 폰트 | `config/fonts.lua` | `JetBrainsMono Nerd Font` 고정, mac 12 / 그 외 9 |
| 스크롤백·하이퍼링크·동작 | `config/general.lua` | |

## 플랫폼 분기

`utils/platform.lua`가 `is_win` / `is_mac` / `is_linux`를 제공한다. 하드코딩 대신 항상 이 모듈을 통해 분기하라.

```lua
local platform = require('utils.platform')
local size = platform.is_mac and 12 or 9
```

키 조합은 `config/bindings.lua`의 `mod` 테이블을 쓴다 — mac은 `SUPER`, win/linux는 `ALT`(Windows 키 단축키와 충돌 회피).

## 코드 스타일

`.stylua.toml`: 스페이스 **3칸** 들여쓰기, 100열, 작은따옴표 선호, 함수 호출 괄호 항상.
`.luacheckrc`: `std = luajit`, 최대 150열, 경고 241 무시, `utils/backdrops.lua`는 212도 무시.

수동으로 정렬을 맞추려 애쓰지 마라. 작성 후 `wezterm-config-verify` 스킬로 검사하고 stylua가 고치게 하라.

기존 파일의 LuaLS 주석 관용구(`---@class`, `---@param`, `---@return`)를 따라간다.

## 편집 후

반드시 `wezterm-config-verify` 스킬을 실행한다. 모듈 하나를 고칠 때마다 즉시 — 여러 변경을 쌓은 뒤 검증하면 `Config:append`의 조용한 중복 무시가 어느 변경 탓인지 분리되지 않는다.

`automatically_reload_config = true`이므로 저장 즉시 실행 중인 WezTerm에 반영된다. 깨진 설정을 저장하면 사용자의 터미널에 즉시 에러가 뜬다 — 저장 전에 문법을 확인하라.
