---
name: wezterm-appearance
description: "WezTerm의 색상 스킴·배경 이미지·탭바·상태바 등 시각 요소를 편집한다. 테마/색상 변경, colors/custom.lua 수정, 배경 이미지 추가·교체·순환 동작 변경, 투명도·블러 조정, 탭 타이틀 모양, 좌우 상태바 내용·색상, 새 탭 버튼, 커서 스타일 변경 요청 시 반드시 이 스킬을 사용할 것. 색감 재조정, 이전 테마 변경 보완, 상태바만 다시 수정 요청에도 사용."
---

# WezTerm Appearance — 시각 요소 편집

색상·배경·탭바·상태바를 편집한다. 옵션 스키마·모듈 구조 변경은 `wezterm-config-edit` 스킬 소관이다.

## 색상 — 단일 출처는 `colors/custom.lua`

Catppuccin Mocha 변형(`base`가 `#1f1f28`로 교체됨)이다. 구조는 두 층이다:

1. `mocha` 팔레트 테이블 — 이름별 hex (`text`, `base`, `mauve`, `peach`, …)
2. `colorscheme` — WezTerm 스키마 키(`foreground`, `background`, `cursor_bg`, `ansi`, `brights`, `tab_bar`)에 팔레트를 매핑

`utils/backdrops.lua`와 `config/appearance.lua`가 모두 이 모듈을 require한다. **이벤트 파일에 hex 리터럴을 직접 박지 마라.** 팔레트를 통해 참조해야 테마 교체가 한 곳에서 끝난다.

`mocha` 테이블 위의 `-- stylua: ignore`는 hex 값 열 정렬을 보존한다. 지우지 마라.

## 배경 — 정적 옵션이 아니라 런타임 컨트롤러

`config/appearance.lua`의 `background = backdrops:initial_options(false)`는 **초기값일 뿐**이다. 이후 키바인딩이 `utils/backdrops.lua`의 순환·랜덤·포커스 모드를 호출해 `window:set_config_overrides()`로 덮어쓴다.

배경 **동작**을 바꾸려면 `config/appearance.lua`가 아니라 `utils/backdrops.lua`의 `_create_opts()` / `_create_focus_opts()`를 고쳐라.

현재 레이어 구성(`_create_opts`):

| 레이어 | 내용 | 값 |
|--------|------|-----|
| 1 | 배경 이미지 | `source = { File = ... }`, `horizontal_align = 'Center'` |
| 2 | 색상 오버레이 | `colors.background`, 120% 크기, -10% 오프셋, `opacity = 0.94` |

투명도를 바꾸려면 레이어 2의 `opacity`를 조정한다. 값이 낮을수록 이미지가 선명해진다.

### 배경 이미지 추가

`backdrops/`에 파일을 넣기만 하면 된다. `set_images()`가 글롭으로 자동 수집한다:

```
*.{jpg,jpeg,png,gif,bmp,ico,tiff,pnm,dds,tga}
```

현재 58장. **목록을 코드에 하드코딩하지 마라.**

## 탭바·상태바 — `utils/cells.lua`

`events/{left-status,right-status,tab-title,new-tab-button}.lua`가 `Cells`를 써서 `wezterm.format` 아이템을 조립한다.

```lua
Cells:new()
   :add_segment(id, text, color, attributes)   -- color = { fg = ..., bg = ... }
   :update_segment_text(id, text)
   :update_segment_colors(id, color)
   :render(ids)        -- 지정 세그먼트만
   :render_all()
   :reset()
```

세그먼트를 **id로 관리**하는 것이 핵심이다. 상태 갱신 시 전체를 다시 만들지 말고 `update_segment_*`로 해당 id만 고쳐라 — 상태바는 `status_update_interval = 1000`으로 초당 갱신되므로 재구성 비용이 누적된다.

## Nerd Font 글리프

폰트는 `JetBrainsMono Nerd Font`로 고정돼 있다(`config/fonts.lua`). 상태바·탭 타이틀의 구분자·아이콘은 이 폰트의 글리프에 의존한다. 새 글리프를 넣기 전에 실제로 존재하는 코드포인트인지 확인하라 — 없으면 두부(tofu) 사각형으로 렌더된다.

## 대비를 근거로 판단하라

이 설정은 **이미지 배경 위에 텍스트를 올린다.** 새 전경색이나 배경 이미지를 제안할 때는 이미지의 가장 밝은 영역과 가장 어두운 영역 **양쪽에서** 본문 텍스트가 읽히는지 따져라. 레이어 2의 색상 오버레이(`opacity = 0.94`)가 대비를 확보하는 장치이므로, 오버레이를 걷어내는 변경은 가독성을 함께 검토해야 한다.

`focus_on` 모드는 이미지를 완전히 걷고 단색(`focus_color`, 기본값은 `colors.background`)만 남긴다 — 가독성이 필요한 작업용 모드다.

## 편집 후

`wezterm-config-verify` 스킬로 검증한다. `automatically_reload_config = true`이므로 저장 즉시 실행 중인 터미널에 반영되어 눈으로 확인할 수 있다.

`config/appearance.lua`는 `wezterm-config-edit`와 공유하는 파일이다. 수정 전에 다른 에이전트가 작업 중인지 확인하라.
