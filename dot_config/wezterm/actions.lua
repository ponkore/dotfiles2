local wezterm = require 'wezterm'
local M = {}

function M.apply(config)
  local is_mac = wezterm.target_triple:find("darwin") ~= nil
  config.default_prog = is_mac and { "zsh" } or { "nyagos.exe" }
  config.launch_menu = {
    {
      label = "Nyagos",
      args = {"nyagos.exe"},
      cwd = "C:/Projects",
    },
    {
      label = "Powershell",
      args = {"powershell.exe"},
    },
    {
      label = "ssh taigei.local",
      args = {"ssh.exe", "taigei.local"},
    },
    {
      label = "ssh no-sinker01.ddns.net",
      args = {"ssh.exe", "no-sinker01.ddns.net"},
    },
    {
      label = "Bash",
      args = {"bash", "-l"},
    },
  }
end

return M
