-- Floating windows
hl.window_rule({ match = { tag = "floating-window" }, float = true })
hl.window_rule({ match = { tag = "floating-window" }, center = true })
hl.window_rule({ match = { tag = "floating-window" }, size = { 800, 600 } })

-- Real applications, matched on their own class.
hl.window_rule({ match = { class = "(org.gnome.NautilusPreviewer|com.gabm.satty)" }, tag = "+floating-window" })

-- TUIs the desktop opens in a terminal. Ghostty cannot set a Wayland app id -- every
-- window it opens is com.mitchellh.ghostty -- so these are matched on the title each
-- launcher passes with --title instead. Scoped to ghostty's class as well, or any
-- window that happened to be called "Desktop" would start floating.
hl.window_rule({
  match = {
    class = "^(com\\.mitchellh\\.ghostty)$",
    title = "^(Agent .*|Bluetui|Gdu|Impala|Wiremix|Desktop|About|TUI\\.float)$",
  },
  tag = "+floating-window",
})
hl.window_rule({
  match = {
    class = "(xdg-desktop-portal-gtk|sublime_text|DesktopEditors|org.gnome.Nautilus)",
    title = "^(Open.*Files?|Open [F|f]older.*|Save.*Files?|Save.*As|Save|All Files)",
  },
  tag = "+floating-window",
})
hl.window_rule({ match = { class = "org.gnome.Calculator" }, float = true })

-- Fullscreen screensaver
hl.window_rule({ match = { class = "^(com\\.mitchellh\\.ghostty)$", title = "^(org\\.desktop\\.screensaver)$" }, fullscreen = true })
hl.window_rule({ match = { class = "^(com\\.mitchellh\\.ghostty)$", title = "^(org\\.desktop\\.screensaver)$" }, float = true })

-- No transparency on media windows
hl.window_rule({
  match = { class = "^(zoom|vlc|mpv|org.kde.kdenlive|com.obsproject.Studio|com.github.PintaProject.Pinta|imv|org.gnome.NautilusPreviewer)$" },
  opacity = "1 1",
})
