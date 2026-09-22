-- Change the default look'n'feel
hl.config({
  -- https://wiki.hypr.land/Configuring/Variables/#general
  general = {
    gaps_in = 1,
    gaps_out = 2,
    border_size = 1,

    -- Use master layout instead of dwindle
    -- layout = "master",
  },

  -- https://wiki.hypr.land/Configuring/Variables/#decoration
  decoration = {
    -- Round window corners, the same 8 as the shell's Style.radius so windows, panels and
    -- the bar share one corner. Smart gaps below square a window off again while it has
    -- a workspace to itself and there is no gap for a corner to show against.
    rounding = 8,
  },

  -- https://wiki.hypr.land/Configuring/Dwindle-Layout/
  dwindle = {
    -- Avoid overly wide single-window layouts on wide screens
    -- single_window_aspect_ratio = "1 1",
  },

  -- https://wiki.hypr.land/Configuring/Variables/#animations
  animations = {
    -- enabled = false,
  },
})

-- Smart Gaps
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1]" }, border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1]" }, rounding = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1]" }, border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1]" }, rounding = 0 })
