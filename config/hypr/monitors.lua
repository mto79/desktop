-- See https://wiki.hypr.land/Configuring/Monitors/
-- List current monitors and resolutions possible: hyprctl monitors
-- Format: hl.monitor({ output = port, mode = resolution, position = ..., scale = ... })
-- You must relaunch Hyprland after changing any envs (use Super+Esc, then Relaunch)
--
-- desktop-cmd-monitors-switch writes this file for the layout it picks; this copy is what
-- a fresh install starts from, before the first screen is plugged in.

-- hl.env("GDK_SCALE", "1")
-- hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.25 })

-- Optimized for retina-class 2x displays, like 13" 2.8K, 27" 5K, 32" 6K.

-- Good compromise for 27" or 32" 4K monitors (but fractional!)
-- hl.env("GDK_SCALE", "1.75")
-- hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.666667 })

-- Straight 1x setup for low-resolution displays like 1080p or 1440p
-- hl.env("GDK_SCALE", "1")
-- hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Example for Framework 13 w/ 6K XDR Apple display
-- hl.monitor({ output = "DP-5", mode = "6016x3384@60", position = "auto", scale = 2 })
-- hl.monitor({ output = "eDP-1", mode = "2880x1920@120", position = "auto", scale = 2 })

-- Example for Lenovo X1 Carbon laptop
-- hl.monitor({ output = "eDP-1", mode = "3840x2160@60.0", position = "0x0", scale = 2.0 })

-- The lid switch example hyprland.conf carried used `hyprctl keyword monitor`, which a Lua
-- config does not take; see https://wiki.hypr.land/Configuring/ for switch binds.
