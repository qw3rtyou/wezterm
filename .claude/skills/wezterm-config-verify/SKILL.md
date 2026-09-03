---
name: wezterm-config-verify
description: "WezTerm Lua 설정 변경을 포맷(stylua)·린트(luacheck)·실제 로드·중복 옵션 키·참조 실재 5단으로 검증한다. 설정 파일을 수정한 직후, 'CI 통과하는지 확인', '설정 안 깨졌나 확인', '린트 돌려줘', '포맷 확인', 'wezterm 설정 검증' 요청 시 반드시 이 스킬을 사용할 것. 검증 재실행, 실패 후 재확인, 특정 파일만 다시 검증 요청에도 사용."
---

# WezTerm Config Verify — 설정 변경 검증

WezTerm 설정 변경이 CI를 통과하고 실제로 로드되는지 확인한다.

## 실행

```bash
bash .claude/skills/wezterm-config-verify/scripts/verify.sh
```

종료 코드 0 = 수행된 모든 검사 통과, 1 = 하나 이상 실패.

**`SKIP`을 통과로 읽지 마라.** 검증되지 않은 것과 통과한 것은 다르다. 도구가 없거나 검사가 성립하지 않는 상황을 통과로 뭉개면 CI에서 터진다.

## 5단 검사

| 검사 | 방법 | CI 대응 |
|------|------|---------|
| 포맷 | `stylua --line-endings Windows -g '!**/init.lua' -g '!**/opts-validator.lua' --check ...` | `.github/workflows/lint.yml` (인자 다름 — 아래 참조) |
| 린트 | `luacheck wezterm.lua colors/* config/* events/* utils/*` | 같은 파일 |
| 로드 | `wezterm ls-fonts` 후 stderr의 `ERROR` 검사 | CI에 없음 — 로컬 전용 |
| 중복키 | `scripts/check-duplicate-keys.sh` 정적 검사 | CI에 없음 — 로컬 전용 |
| 참조 | `scripts/check-references.sh` — WSL 배포판·실행 파일 실재 확인 | CI에 없음 — 로컬 전용 |

린트 인자는 CI와 정확히 일치시켰다. 포맷은 아래 세 가지 이유로 로컬 호출이 다르다.

## 포맷 검사 — 로컬 호출이 CI와 다른 이유 (모두 실측 확인)

**1. 작업 트리가 CRLF다.** `core.autocrlf=true`라 체크아웃된 파일은 CRLF인데 `.stylua.toml`은
`line_endings = "Unix"`다. 보정 없이 돌리면 **모든 파일이 통째로 diff로 잡힌다.** git이 커밋 시
LF로 정규화하므로 CI(리눅스)에서는 문제가 없다. 로컬에서는 `--line-endings Windows`를 줘야
줄바꿈 차이가 걷히고 내용 차이만 보인다.

> 감지 요령: `$(head -1 file)`로는 `\r`을 볼 수 없다. MSYS가 명령 치환에서 CRLF를 번역해
> 버리기 때문이다. `head -c 400 file | od -An -c | grep '\\r'`처럼 od를 거쳐야 한다.

**2. stylua 2.x는 Lua 5.2의 `goto`/`::label::`을 파싱하지 못한다.**
`config/init.lua`와 `utils/opts-validator.lua`가 여기 걸려 `expected label name after ::`
에러를 낸다. `.stylua.toml`에 `syntax = "Lua52"`를 넣으면 해결되지만, CI가 쓰는 0.19.1이
이 키를 모를 수 있어 건드리지 않고 두 파일을 제외했다.

**3. CI의 제외 글롭은 실제로 아무것도 제외하지 못한다.**
`-g '!/config/init.lua'`는 선행 슬래시 때문에 매칭되지 않는다. 동작하는 형태는
`'!**/init.lua'`다. 로컬 스크립트는 동작하는 쪽을 쓴다.

**버전 차이:** CI는 stylua **0.19.1** 고정, 로컬은 winget이 제공하는 **2.5.2**다. 두 버전이
같은 코드에 대해 다른 결과를 낼 수 있다. 로컬을 통과시킨 뒤 CI가 포맷으로 실패하면, 원인은
코드가 아니라 버전 차이일 가능성이 높다. 그때는 `.github/workflows/lint.yml`의 `version:`을
로컬과 맞춰라.

**수렴:** stylua는 한 번에 최종형에 도달하지 않을 수 있다. 긴 호출을 감싸는 경우 1회 더
돌려야 `--check`가 통과하는 사례가 있었다. 실패가 남으면 한 번 더 포맷하고 재검사하라.

## 로드 검사의 두 가지 제약 (실측 확인)

**1. `--config-file`은 진입 파일만 바꾼다.**
`require('config.appearance')` 같은 모듈은 여전히 표준 설정 디렉토리(`WEZTERM_CONFIG_DIR` 또는 `~/.config/wezterm`)에서 해석된다. 레포 사본에 `--config-file`을 겨눠도 실제로 읽히는 것은 라이브 설정의 모듈이다 — 사본의 `config/fonts.lua`를 Consolas로 바꿔도 `ls-fonts`는 JetBrainsMono를 그대로 보고한다.

따라서 **로드 검사는 이 레포가 라이브 설정 디렉토리일 때만 의미가 있다.** 스크립트는 `ROOT`가 설정 디렉토리와 다르면 이 검사를 `SKIP`으로 보고한다. 사본을 검사해 통과가 떴다면 그것은 사본이 아니라 라이브 설정을 본 결과다.

> 환경변수로 우회할 수 없다. **`WEZTERM_CONFIG_DIR` 이라는 변수는 존재하지 않는다** — 설정해도
> 조용히 무시된다(실측). `WEZTERM_CONFIG_FILE` 은 실제로 동작하지만 `--config-file` 과 똑같이
> 진입 파일만 바꿀 뿐, 모듈은 여전히 `~/.config/wezterm` 에서 해석된다. 사본 검증은 어느 쪽으로도
> 불가능하다.

**2. 상대경로를 넘기면 가짜 실패가 뜬다.**
`--config-file`에 상대경로를 주면 `wezterm.config_dir`가 어긋나 `utils/backdrops.lua`의 `set_images()` 글롭이 이미지를 0장 반환하고, 멀쩡한 설정에 대해 다음이 출력된다:

```
Error processing background.source ... Expected a valid `BackgroundSource` variant name
as single key in object, but there are 0 keys.  { "horizontal_align": "Center", "source": {} }
```

이 메시지를 보면 설정을 고치기 전에 먼저 호출 방식을 의심하라. 스크립트는 `--config-file`을 아예 쓰지 않아 이 함정을 피한다.

**3. 종료 코드를 믿지 마라.** WezTerm은 설정이 깨져도 기본 설정으로 폴백하며 **종료 코드 0**을 반환한다. 성패는 stderr의 `ERROR` 문자열로만 판정된다.

## 중복 옵션 키 — 런타임으로는 잡히지 않는다

`config/init.lua`의 `Config:append`는 이미 존재하는 키를 만나면 덮어쓰지 않고 `wezterm.log_warn` 한 줄만 남긴 뒤 **건너뛴다.**

```lua
if self.options[k] ~= nil then
   wezterm.log_warn('Duplicate config option detected: ', { old = ..., new = ... })
   goto continue
end
```

그런데 이 경고는 **설정이 정상 로드될 때 `wezterm ls-fonts`의 stdout에도 stderr에도 나타나지 않는다** (실측 확인 — `WEZTERM_LOG=trace`로도 보이지 않으며, GUI 디버그 오버레이로만 간다). 즉 새로 추가한 옵션이 조용히 무시돼도 런타임 관찰로는 알 수 없다.

그래서 소스를 직접 읽는 정적 검사를 쓴다:

```bash
bash .claude/skills/wezterm-config-verify/scripts/check-duplicate-keys.sh
```

`config/*.lua`(init.lua 제외)에서 들여쓰기 정확히 3칸인 최상위 키를 추출해 모듈 간 충돌을 찾는다. 충돌이 나오면 `wezterm.lua`의 append 순서상 **앞선 모듈이 이긴다**:

```
appearance → bindings → domains → fonts → general → launch
```

먼저 정의된 모듈에서 값을 고치고, 나중 모듈의 중복 정의는 지워라.

## 참조 실재 검사

wezterm 은 설정이 **없는 WSL 배포판이나 실행 파일**을 가리켜도 로드 단계에서 아무 말도 하지
않는다. 그 도메인을 열거나 단축키를 누르는 순간에야 조용히 실패한다.

실제 사례: `wsl_domains` 가 `Ubuntu-22.04` 를 가리켰지만 설치된 이름은 `Ubuntu` 였다.
그 결과 `Ctrl+Alt+T` 단축키와 launch_menu 의 WSL 항목, 도메인이 전부 죽어 있었는데
로드 검사·린트·포맷은 모두 통과했다. 이 사각지대를 메우는 검사다.

`launch_menu` 쪽은 실패로 올리지 않고 정보로만 보고한다 — 다른 OS 분기의 프로그램
(`fish`, `zsh`)이 이 머신에 없는 것은 정상이기 때문이다.

## 검증이 아닌 것

파일 존재 여부나 문법만 보는 것은 이 레포에서 의미가 약하다. 실제 위험은 경계면에 있다:

- 모듈이 노출한 옵션명 ↔ WezTerm Config 스키마 (오타는 `Error converting lua value`로 나타난다)
- `colors/custom.lua`가 정의한 키 ↔ `events/*.lua`가 참조하는 키
- `config/appearance.lua`의 `background` 초기값 ↔ `utils/backdrops.lua`의 런타임 재정의

변경이 이 경계를 건드렸다면 양쪽 파일을 함께 읽고 값이 실제로 이어지는지 대조하라.

## 점진적 검증

전체 작업을 끝낸 뒤 몰아서 하지 말고 **모듈 하나를 고칠 때마다 즉시** 실행하라. 이 레포는 모듈 간 결합이 `Config:append`라는 조용한 지점에 몰려 있어, 여러 변경을 쌓은 뒤 검증하면 어느 변경이 원인인지 분리되지 않는다.

## 도구 설치

stylua는 설치돼 있다(winget, 2.5.2). winget이 PATH에 추가하지만 이미 열려 있던 셸에는
반영되지 않으므로, 스크립트가 PATH에서 못 찾으면 winget 패키지 디렉토리를 직접 뒤진다.

luacheck는 설치돼 있지 않다 — 루아 런타임과 luarocks 체인이 필요해 비용 대비 이득이 작다고
판단했다. 필요하면 아래로 설치하고, 설치되면 스크립트가 자동으로 검사에 포함한다.

```bash
winget install DEVCOM.LuaJIT            # luacheck 실행용 런타임
# 이후 luarocks 로 luacheck 설치
```

> CI는 stylua **0.19.1**로 고정돼 있다. 로컬에 최신(2.x)을 설치하면 포맷 결과가 달라져 로컬 통과가 CI 실패로 이어질 수 있다. 불일치가 확인되면 `.github/workflows/lint.yml`의 버전을 로컬과 맞추는 편이 낫다.
