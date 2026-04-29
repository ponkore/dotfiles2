local wezterm = require 'wezterm'

local M = {}

function M.apply(config)
  --
  -- font
  --
  config.font = wezterm.font_with_fallback({
    { family = "HackGen Console NF" },
    { family = "SauceCodePro Nerd Font Mono" },
  })
  local is_mac = wezterm.target_triple:find("apple-darwin") ~= nil
  config.font_size = is_mac and 14.0 or 12.0
  config.adjust_window_size_when_changing_font_size = false
  config.treat_east_asian_ambiguous_width_as_wide = false
  --  config.unicode_version = 14
  config.warn_about_missing_glyphs = false

  --
  -- tabbar
  --
  config.hide_tab_bar_if_only_one_tab = true
  config.use_fancy_tab_bar = true
  config.colors = {
    tab_bar = {
      background = '#1a1a2e',
      active_tab = {
        bg_color = '#f5a623',  -- 明るいオレンジ（目立つ色）
        fg_color = '#000000',  -- 黒文字（コントラスト確保）
      },
      inactive_tab = {
        bg_color = '#2d2d2d',
        fg_color = '#808080',
      },
      inactive_tab_hover = {
        bg_color = '#3d3d3d',
        fg_color = '#c0c0c0',
      },
      new_tab = {
        bg_color = '#2d2d2d',
        fg_color = '#808080',
      },
    },
  }

  --
  -- window / pane / theme
  --
  -- config.window_decorations = "RESIZE"
  -- config.color_scheme = "Solarized" -- "Wez" -- 自分の好きなテーマ探す https://wezfurlong.org/wezterm/colorschemes/index.html
  -- Wez, Dracura (Official), Aura
  config.window_background_opacity = 0.93
  config.inactive_pane_hsb = {
    saturation = 0.9,
    brightness = 0.7,
  }
  config.window_padding = {
    left = 4,
    right = 4,
    top = 2,
    bottom = 2,
  }
  -- config.pane_focus_follows_mouse = true
end

return M
