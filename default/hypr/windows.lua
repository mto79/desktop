-- See https://wiki.hypr.land/Configuring/Window-Rules/ for more
hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })

-- Opacity values used when transparency is toggled on (opaque by default)
hl.window_rule({ match = { class = ".*" }, opaque = true })
hl.window_rule({ match = { class = ".*" }, opacity = "0.97 0.9" })

-- Fix some dragging issues with XWayland
hl.window_rule({
  match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
  no_focus = true,
})

-- App-specific tweaks
source("~/.local/share/desktop/default/hypr/apps.lua")
