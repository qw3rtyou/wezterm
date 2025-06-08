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
         assume_shell = 'Posix'
      },
      {
         name = 'kali-local',
         remote_address = '211.250.216.249',
         username = 'foo1',
         -- WezTerm의 올바른 SSH 설정 구조
         ssh_option = {
            identityfile = 'C:\\Users\\chjw1\\.ssh\\local_kali',
            port = '22',  -- 문자열로 변경
         },
         default_prog = { 'zsh', '-l' },
         assume_shell = 'Posix',
         multiplexing = 'None',
       }
   },

   -- ref: https://wezfurlong.org/wezterm/multiplexing.html#unix-domains
   unix_domains = {},

   -- ref: https://wezfurlong.org/wezterm/config/lua/WslDomain.html
   wsl_domains = {
      {
         name = 'WSL:Ubuntu-22.04',
         distribution = 'Ubuntu-22.04',  -- 실제 설치된 배포판 이름
         username = 'foo1',              -- 실제 WSL 사용자명
         default_cwd = '/home/foo1',     -- 실제 홈 디렉토리
         default_prog = { 'zsh', '-l' }, -- zsh 셸 사용
      },
   },
}
