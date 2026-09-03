---
name: wezterm-harness
description: "WezTerm 설정 에이전트 팀(config-engineer, appearance-designer, config-validator)을 조율하는 오케스트레이터. WezTerm 설정 변경·기능 추가·테마 변경·키바인딩 추가·상태바 개편 등 이 레포의 설정 작업 요청 시 사용. 후속 작업: 설정 변경 수정, 부분 재실행, 업데이트, 보완, 다시 실행, 이전 결과 개선, '아까 그 변경 되돌려줘', '색만 다시' 요청 시에도 반드시 이 스킬을 사용. 단순 질문(설정 위치 확인, 옵션 의미 설명)은 팀을 만들지 말고 직접 답한다."
---

# WezTerm Harness Orchestrator

WezTerm 설정 변경을 에이전트 팀으로 수행한다.

## 실행 모드: 에이전트 팀 (생성-검증 / Producer-Reviewer)

두 생성자(engineer, designer)가 병렬로 작업하고, 검증자가 게이트 역할을 한다.

## 에이전트 구성

| 팀원 | 에이전트 타입 | 역할 | 스킬 | 출력 |
|------|-------------|------|------|------|
| config-engineer | config-engineer | 옵션·키바인딩·이벤트·플랫폼 분기 구현 | `wezterm-config-edit` | `_workspace/01_engineer_changes.md` |
| appearance-designer | appearance-designer | 색상·배경·탭바·상태바 | `wezterm-appearance` | `_workspace/02_designer_changes.md` |
| config-validator | general-purpose | 포맷·린트·로드 검증 | `wezterm-config-verify` | `_workspace/03_validator_report.md` |

모든 `Agent`/`TeamCreate` 호출에 `model: "opus"`를 명시한다.

## 규모 판단 — 팀을 만들지 않아도 되는 경우

이 레포는 2,100줄 규모다. **변경이 파일 하나에 국한되고 검증이 한 번이면 팀을 만들지 마라.** 해당 스킬(`wezterm-config-edit` 또는 `wezterm-appearance`)을 직접 따르고 `wezterm-config-verify`로 확인하는 편이 빠르다.

팀을 구성하는 기준:
- 구현과 시각 요소가 **동시에** 걸린다 (예: 새 상태바 위젯 = 이벤트 로직 + 색상·글리프)
- 파일 3개 이상을 가로지른다
- 플랫폼 분기와 외관이 함께 바뀐다

## 워크플로우

### Phase 0: 컨텍스트 확인

1. `_workspace/` 존재 여부 확인
2. 실행 모드 결정:
   - **미존재** → 초기 실행. Phase 1로 진행
   - **존재 + 부분 수정 요청** → 부분 재실행. 해당 에이전트만 재호출하고 이전 산출물 경로를 프롬프트에 포함해 기존 결과를 읽고 반영하게 한다
   - **존재 + 새 요청** → 새 실행. `_workspace/`를 `_workspace_{YYYYMMDD_HHMMSS}/`로 이동 후 재생성
3. `git status`로 커밋되지 않은 변경이 있는지 확인한다. 있으면 사용자에게 알리고, 그 변경 위에 작업할지 확인받는다 — 이 레포는 사용자의 **실사용 터미널 설정**이며 `automatically_reload_config = true`라 저장 즉시 반영된다.

### Phase 1: 준비

1. 요청을 구현 작업 / 시각 작업 / 양쪽으로 분류
2. `_workspace/` 생성, 요구사항을 `_workspace/00_input/request.md`에 저장
3. 변경 대상 파일을 특정한다. `grep -rn '옵션명' config/`로 기존 정의를 먼저 확인 — `Config:append`는 중복 키를 조용히 건너뛴다

### Phase 2: 팀 구성

```
TeamCreate(
  team_name: "wezterm-config-team",
  members: [
    { name: "config-engineer",     agent_type: "config-engineer",     model: "opus",
      prompt: "wezterm-config-edit 스킬을 따라 요청된 옵션·키바인딩·이벤트를 구현하라." },
    { name: "appearance-designer", agent_type: "appearance-designer", model: "opus",
      prompt: "wezterm-appearance 스킬을 따라 색상·배경·상태바를 편집하라." },
    { name: "config-validator",    agent_type: "general-purpose",     model: "opus",
      prompt: ".claude/agents/config-validator.md 의 역할을 맡아 wezterm-config-verify 스킬로 검증하라." }
  ]
)
```

작업 등록 시 검증 작업은 각 구현 작업에 `depends_on`으로 묶되, **모듈 단위로 쪼갠다.** 전체 완성 후 검증 1회가 아니라 모듈마다 검증이 붙어야 한다.

### Phase 3: 구현

**실행 방식:** 팀원 자체 조율

**통신 규칙:**
- `config-engineer`는 시각 요소로 분류된 작업을 `appearance-designer`에게 SendMessage로 넘긴다
- `config/appearance.lua`는 두 에이전트가 공유하는 파일이다. 수정 전 반드시 상대에게 알린다
- 각 에이전트는 모듈 하나를 끝낼 때마다 `config-validator`에게 검증을 요청한다
- `config-validator`는 실패를 담당 에이전트에게 직접 반환한다. 리더에게는 통과 여부만 보고한다

### Phase 4: 검증 통합

1. `TaskGet`으로 전 작업 완료 확인
2. `_workspace/03_validator_report.md` 수집
3. `bash .claude/skills/wezterm-config-verify/scripts/verify.sh` 최종 1회 실행
4. `SKIP` 항목을 통과로 읽지 않는다. stylua·luacheck가 미설치면 "로컬 미검증, CI에서 확인 필요"로 명시 보고한다

### Phase 5: 정리

1. 팀 정리 (`TeamDelete`)
2. `_workspace/` 보존
3. 변경 요약 + 검증 결과를 사용자에게 보고
4. `CLAUDE.md`의 변경 이력 테이블에 이번 변경을 기록한다
5. 사용자에게 피드백을 요청한다 — "결과에서 개선할 부분이 있나요?" 강요하지 않되 기회는 반드시 준다

## 데이터 흐름

```
사용자 요청
   └→ _workspace/00_input/request.md
        ├→ config-engineer     → config/ events/ utils/ 수정 → 01_engineer_changes.md
        └→ appearance-designer → colors/ backdrops/ events/ 수정 → 02_designer_changes.md
              ↓ (각 모듈 완료 즉시)
           config-validator → verify.sh → 03_validator_report.md
              ↓ 실패 시 담당 에이전트로 반환 (최대 1회 재시도)
           최종 보고 + CLAUDE.md 변경 이력 갱신
```

## 에러 핸들링

| 상황 | 대응 |
|------|------|
| 검증 실패 | 담당 에이전트가 1회 수정 후 재검증. 재실패 시 해당 변경을 되돌리고 원인과 함께 사용자에게 보고 |
| 중복 옵션 키 검출 (`check-duplicate-keys.sh`) | 실패로 취급. 런타임으로는 보이지 않는 문제다. append 순서상 먼저 정의한 모듈에서 값을 고치고 나중 정의는 삭제 |
| `Error converting lua value` | 옵션명을 추측해 바꾸지 말고 WezTerm 공식 문서에서 확인 후 보고 |
| 도구 미설치 (stylua/luacheck) | 통과가 아니라 **미검증**으로 보고 |
| 두 에이전트가 같은 파일 충돌 | 리더가 순서를 정해 직렬화. 변경을 삭제하지 말고 양쪽 의도를 병기해 사용자에게 확인 |
| 사용자 설정이 깨진 채 남을 위험 | `automatically_reload_config = true`이므로 즉시 되돌린다. 되돌림을 우선하고 원인 분석은 그 다음 |

## 테스트 시나리오

**정상 흐름 — "상태바 오른쪽에 배터리 잔량 추가해줘"**
1. Phase 1: `events/right-status.lua`(구현) + 색상·글리프(시각) 양쪽 → 팀 구성
2. `config-engineer`가 배터리 조회 로직과 세그먼트 갱신을 구현, `appearance-designer`에게 색상·아이콘 요청
3. `appearance-designer`가 `colors/custom.lua` 팔레트에서 색을 고르고 Nerd Font 글리프 확인
4. `config-validator`가 각 수정 직후 `verify.sh` 실행 → 통과
5. 리더가 요약 보고 + `CLAUDE.md` 이력 갱신

**에러 흐름 — 새 옵션이 무시됨**
1. `config-engineer`가 `config/general.lua`에 `font_size`를 추가
2. `verify.sh`의 중복키 정적 검사가 `config/fonts.lua`와 `config/general.lua` 충돌을 검출 (런타임 출력에는 아무 경고도 나타나지 않는다)
3. `config-validator`가 "`config/fonts.lua`가 먼저 append되어 무시됨"을 반환
4. `config-engineer`가 `config/general.lua`의 추가를 되돌리고 `config/fonts.lua`에서 값을 수정
5. 재검증 통과
