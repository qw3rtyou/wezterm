# CLAUDE.md

## 하네스: WezTerm 설정

**목표:** WezTerm Lua 설정 변경을 구현·시각·검증 3역할로 나눠 수행하고, CI(stylua·luacheck)와 실제 로드까지 통과시킨다.

**트리거:** WezTerm 설정 변경·기능 추가·테마/키바인딩/상태바 작업 요청 시 `wezterm-harness` 스킬을 사용하라. 단순 질문(옵션 의미, 파일 위치)은 직접 응답 가능. 파일 하나로 끝나는 변경은 팀을 만들지 말고 `wezterm-config-edit` 또는 `wezterm-appearance` 스킬을 직접 따르고 `wezterm-config-verify`로 확인하라.

**주의:** 이 레포는 사용자의 실사용 WezTerm 설정이며 `automatically_reload_config = true`다. 저장 즉시 실행 중인 터미널에 반영되므로, 깨진 상태로 저장하지 마라. **단 `ssh_domains` 는 예외로 시작 시에만 읽힌다** — 도메인을 고쳤다면 wezterm 재시작이 필요하다는 점을 반드시 알려라.

**변경 이력:**

| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-09-03 | 초기 구성 (생성-검증 패턴, 3에이전트) | 전체 | - |
| 2026-09-03 | kali-local SSH 세션 지속성: 원격 tmux 자동 attach (tmux 없으면 zsh 폴백) | config/domains.lua | 원격 세션이 곧 끊겨 12시간+ 유지 요청. 설치된 wezterm 20240203 에는 ServerAliveInterval 미포함이라 keepalive 옵션이 무효 |
| 2026-09-03 | kali-local identityfile 을 wezterm.home_dir 파생으로 교체 | config/domains.lua | 기존 값이 이 머신에 없는 C:\Users\chjw1 경로였음 |
| 2026-09-03 | stylua 2.5.2 설치 후 검증 스크립트 연동 (CRLF 보정, goto 라벨 파일 제외, winget 경로 탐색) | 검증 스크립트 + 스킬 | 로컬 포맷 검사가 CRLF 때문에 전 파일을 오탐하던 문제 |
| 2026-09-03 | 기존 포맷 드리프트 정리 | utils/backdrops.lua, events/right-status.lua | 포맷 게이트를 초록으로 만들어 실제로 쓰이게 함 |
| 2026-09-03 | kali-local·kali-vm 에 serveraliveinterval=60 추가 | config/domains.lua | 현재 stable 20240203 에서는 무시되지만, 2025-05-14 커밋 909573fa 이후 빌드로 올리면 즉시 유효. keepalive 는 유휴 끊김만 막고 실제 끊김은 tmux 가 담당 |
| 2026-09-03 | wezterm nightly 20260901 을 %LOCALAPPDATA%\Programs\WezTerm-nightly 에 나란히 설치 | 환경 | serveraliveinterval 을 실제로 유효하게 만들기 위함. stable 은 폴백으로 유지. 설정 호환성은 로드 검사로 사전 확인(에러 0건) |
| 2026-09-03 | 검증 스크립트가 stable·nightly 두 바이너리를 모두 검사하도록 변경 | verify.sh | 사용자가 실제로 띄우는 바이너리가 PATH 의 stable 이 아닐 수 있음 |
| 2026-09-03 | WEZTERM_CONFIG_DIR 전제 제거 | verify.sh, wezterm-config-verify 스킬 | 그런 환경변수는 존재하지 않음(실측). 동작하는 것은 WEZTERM_CONFIG_FILE 이며 그것도 모듈 해석 경로는 못 바꿈 |
| 2026-09-03 | kali-local 의 identityfile 지정 제거 | config/domains.lua | 서버(OpenSSH 9.6, Ubuntu)가 이 머신의 어떤 키도 authorized_keys 에 갖고 있지 않음을 실측 확인. 거부되는 키를 제안할 뿐이라 제거. 실제 인증은 비밀번호 |
| 2026-09-03 | 지속성 실증: 42초 끊김 동안 원격 프로세스 계속 실행 확인 | (검증) | tmux 세션 main 재부착 시 카운터 tick 6 → 27 로 진행. destroy-unattached=off, tmux 3.4, 서버 uptime 35일 |
| 2026-09-03 | 작업 표시줄 WezTerm 바로가기를 nightly 로 변경 | (환경) | 사용자 요청. 시작 메뉴 항목은 ProgramData 라 관리자 권한 필요해 stable 유지(폴백) |
| 2026-09-03 | kali-local tmux 를 눈에 띄지 않게: status off / mouse on | config/domains.lua | 셸이 tmux 로 바뀐 줄 알고 zsh 를 원하셨으나 실제로는 tmux 안의 zsh. 상태바만 걷어 순수 zsh 처럼 보이게 하고 지속성은 유지 |
| 2026-09-03 | tmux 옵션 적용을 `new -A \; set` 에서 detached→set→attach 순서로 변경 | config/domains.lua | 기존 세션에 attach 할 때 `\;` 로 이어붙인 set 이 적용되지 않음(실측) |
| 2026-09-03 | ssh_domains 는 리로드로 반영되지 않고 재시작이 필요하다는 사실 문서화 | CLAUDE.md, wezterm-config-edit | 실측 확인 + wezterm 업스트림 이슈 #1279/#4284/#6650/#7072. 재시작 전 테스트를 '적용 안 됨'으로 오판하기 쉬움 |
| 2026-09-03 | 탭 제목 절단을 바이트→표시 칸 기준으로 수정 | events/tab-title.lua | string.len/sub 가 한글 문자 중간을 잘라 format-tab-title 이 계속 실패(incomplete utf-8). wezterm.column_width/truncate_right 로 교체. '하네스 스킬'=16바이트/11칸 |
| 2026-09-03 | 알파벳 키 바인딩 30개를 phys: 물리키로 변환 | config/bindings.lua | 문자 기준 바인딩이 한글 입력 모드에서 매칭되지 않아 ALT+W 등이 동작하지 않음 |
| 2026-09-03 | 배터리 없는 기기에서 배터리 세그먼트 미표시 | events/right-status.lua | 이 머신은 battery_info()가 빈 목록이라 상태바 끝에 separator2 만 덩그러니 남았음 |
| 2026-09-03 | WSL 배포판 이름 Ubuntu-22.04 → Ubuntu (4곳) | config/{domains,launch,bindings}.lua | 실제 설치명은 'Ubuntu'. 잘못된 이름 탓에 Ctrl+Alt+T 단축키·launch_menu 항목·WSL 도메인이 모두 죽어 있었음 |
| 2026-09-03 | 참조 실재 검사 추가(5단째) | check-references.sh, verify.sh | 없는 WSL 배포판/실행 파일을 가리켜도 로드·린트·포맷은 전부 통과하는 사각지대를 메움 |
| 2026-09-03 | Lua Language Server 설치 후 정적 분석 | (환경) | Information 수준까지 문제 없음 확인. .luarc.json 이 이미 있어 추가 설정 불필요 |
| 2026-09-03 | wsl_domains 도 재시작 필요임을 확인·문서화 | wezterm-config-edit | `wezterm cli spawn --domain-name <없는이름>` 이 실행 중 인스턴스의 도메인 목록을 알려준다 |
| 2026-09-03 | launch_menu 의 Nushell 항목 제거 (Windows·mac 각 1곳) | config/launch.lua | `nu` 미설치라 실행 시 실패하는 항목이었고 사용자가 쓰지 않음 |
| 2026-09-03 | launch_menu 의 Git Bash 항목 복구 | config/launch.lua | 포크 원저자 경로(C:\Users\kevin\scoop\...)로 주석 처리돼 있었음. 이 머신의 실제 경로 C:\Program Files\Git\bin\bash.exe 로 고쳐 활성화(-l 로그인 셸) |
| 2026-09-03 | 참조 검사가 Windows 절대경로도 판정하도록 개선 | check-references.sh | Lua 문자열의 이스케이프된 백슬래시를 되돌려 파일 존재로 확인. 잘못된 경로 주입 테스트로 검출 확인 |
| 2026-09-03 | CI 실패 수정: 미사용 변수·공백 줄 | config/domains.lua, config/bindings.lua | W211 미사용 wezterm require(identityfile 제거하며 생김), W611 공백만 있는 줄(기존부터 있었음) |
| 2026-09-03 | luacheck 를 CI 동일 도커 이미지로 실행하도록 변경 | verify.sh, 검증 스킬 | 로컬 미설치라 SKIP 하고 푸시했다가 CI 에서 실패. Lua 툴체인 없이 CI 와 동일 결과를 얻는다 |
