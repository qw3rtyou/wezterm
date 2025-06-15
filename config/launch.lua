local platform = require('utils.platform')

local options = {
   default_prog = {},
   launch_menu = {},
}

if platform.is_win then
   options.default_prog = { 'pwsh', '-NoLogo' }
   options.launch_menu = {
      { label = 'PowerShell Core', args = { 'pwsh', '-NoLogo' } },
      { label = 'PowerShell Desktop', args = { 'powershell' } },
      { label = 'Command Prompt', args = { 'cmd' } },
      { label = 'Nushell', args = { 'nu' } },
      { label = 'WSL Ubuntu', args = { 'wsl', '-d', 'Ubuntu-22.04' } },
      -- SSH 도메인들 (올바른 방법)
      { label = 'Kali Local (SSH)', domain = { DomainName = 'kali-local' } },
      { label = 'Kali VM (SSH)', domain = { DomainName = 'kali-vm' } },
      { label = 'WSL SSH', domain = { DomainName = 'wsl.ssh' } },
      -- { label = 'Msys2', args = { 'ucrt64.cmd' } },
      -- { label = 'Git Bash', args = { 'C:\\Users\\kevin\\scoop\\apps\\git\\current\\bin\\bash.exe' } },
   }
elseif platform.is_mac then
   options.default_prog = { '/opt/homebrew/bin/fish', '-l' }
   options.launch_menu = {
      { label = 'Bash', args = { 'bash', '-l' } },
      { label = 'Fish', args = { '/opt/homebrew/bin/fish', '-l' } },
      { label = 'Nushell', args = { '/opt/homebrew/bin/nu', '-l' } },
      { label = 'Zsh', args = { 'zsh', '-l' } },
   }
elseif platform.is_linux then
   options.default_prog = { 'fish', '-l' }
   options.launch_menu = {
      { label = 'Bash', args = { 'bash', '-l' } },
      { label = 'Fish', args = { 'fish', '-l' } },
      { label = 'Zsh', args = { 'zsh', '-l' } },
   }
end

return options
