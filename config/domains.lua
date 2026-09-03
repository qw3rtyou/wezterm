local wezterm = require('wezterm')

return {
   -- ref: https://wezfurlong.org/wezterm/config/lua/SshDomain.html
   -- ssh_domains = {},
   ssh_domains = {
      -- yazi's image preview on Windows will only work if launched via ssh from WSL
      {
         name = 'wsl.ssh',
         remote_address = 'localhost',
         username = 'foo1',
         multiplexing = 'None',
         default_prog = { 'zsh', '-l' }, -- fish 대신 zsh 사용
         assume_shell = 'Posix',
      },
      {
         name = 'kali-vm',
         remote_address = '192.168.40.128',
         username = 'kali',
         -- keepalive — 동작 조건은 kali-local 쪽 주석 참조
         ssh_option = {
            serveraliveinterval = '60',
         },
         default_prog = { 'zsh', '-l' },
         assume_shell = 'Posix',
         multiplexing = 'None',
      },
      {
         name = 'kali-local',
         remote_address = '211.250.216.249',
         username = 'foo1',
         -- keepalive: 유휴 상태에서 NAT/sshd 가 연결을 끊는 것을 막는다.
         -- 주의: libssh 백엔드(ssh_backend 기본값)에서만 동작하고, 2025-05-14 커밋
         -- 909573fa 이후 빌드가 필요하다. stable 20240203 에서는 조용히 무시된다.
         -- 실제 끊김(절전/네트워크 전환)은 이걸로 못 막으므로 tmux 지속성과 함께 쓴다.
         -- WezTerm의 올바른 SSH 설정 구조
         ssh_option = {
            -- identityfile 을 두지 않는다. 이 호스트(OpenSSH 9.6, Ubuntu)는 비밀번호로
            -- 인증하며, 이 머신의 키는 서버 authorized_keys 에 없다 — local_kali 를 지정하면
            -- 거부되는 키를 제안한 뒤 비밀번호로 넘어갈 뿐이다 (2026-09-03 실측).
            -- 원래 값이던 C:\Users\chjw1\.ssh\local_kali 는 이 머신에 존재하지도 않았다.
            port = '22', -- 문자열로 변경
            serveraliveinterval = '60',
         },
         -- 세션 지속성: 접속 시 원격 tmux 세션에 자동 attach 한다.
         -- multiplexing = 'None' 이라 연결이 끊기면 pane 은 사라지지만, 서버의 tmux
         -- 세션은 살아남으므로 재접속하면 하던 작업이 그대로 복귀한다.
         -- 셸은 그대로 zsh 다 — tmux 는 그 zsh 를 감싸는 껍데기일 뿐이다.
         -- status off / mouse on 으로 tmux 를 눈에 띄지 않게 만든다. -t main 으로 걸어
         -- 이 세션에만 적용되고 서버의 다른 tmux 세션은 건드리지 않는다.
         -- new -A 에 \; 로 set 을 이어붙이는 형태는 기존 세션에 붙을 때 적용되지 않았다(실측).
         -- detached 로 보장 → set → attach 순서여야 확실하다.
         -- tmux 가 없는 환경에서도 접속이 실패하지 않도록 zsh 로 폴백한다.
         default_prog = {
            'sh',
            '-lc',
            'command -v tmux >/dev/null 2>&1 || exec zsh -l;'
               .. ' tmux new -d -A -s main;'
               .. ' tmux set -t main status off;'
               .. ' tmux set -t main mouse on;'
               .. ' exec tmux attach -t main',
         },
         assume_shell = 'Posix',
         multiplexing = 'None',
      },
   },

   -- ref: https://wezfurlong.org/wezterm/multiplexing.html#unix-domains
   unix_domains = {},

   -- ref: https://wezfurlong.org/wezterm/config/lua/WslDomain.html
   wsl_domains = {
      {
         name = 'WSL:Ubuntu',
         distribution = 'Ubuntu', -- `wsl -l -q` 의 이름과 정확히 일치해야 한다
         username = 'foo1', -- 실제 WSL 사용자명
         default_cwd = '/home/foo1', -- 실제 홈 디렉토리
         default_prog = { 'zsh', '-l' }, -- zsh 셸 사용
      },
   },
}
