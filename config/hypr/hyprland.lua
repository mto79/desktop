-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/
--
-- The config Hyprland reads: whenever hyprland.lua exists it is read in place of
-- hyprland.conf, decided once at startup, and from 0.57 nothing else is read at all.
--
-- The .conf files beside it are no longer loaded and are kept only until 0.57 as the
-- record of what this was converted from. They are not a way back on their own: the
-- scripts and the bar now speak the Lua dispatchers (`hyprctl dispatch 'hl.dsp...'`,
-- `hyprctl eval`), which a hyprlang session refuses, just as a Lua session refuses the
-- old `hyprctl dispatch workspace 3` and `hyprctl keyword`.

-- hyprland.conf's `source =`: runs another config file, ~ being home. dofile rather than
-- require, since the files live in three places -- the repo's defaults, the active theme,
-- this directory -- and are named by path the way they always were.
function source(path)
  dofile((path:gsub("^~", os.getenv("HOME"))))
end

-- Setup defaults (don't edit these directly!)
source("~/.local/share/desktop/default/hypr/autostart.lua")
source("~/.local/share/desktop/default/hypr/bindings/media.lua")
source("~/.local/share/desktop/default/hypr/bindings/tiling.lua")
source("~/.local/share/desktop/default/hypr/bindings/utilities.lua")
source("~/.local/share/desktop/default/hypr/envs.lua")
source("~/.local/share/desktop/default/hypr/looknfeel.lua")
source("~/.local/share/desktop/default/hypr/input.lua")
source("~/.local/share/desktop/default/hypr/windows.lua")
source("~/.config/desktop/current/theme/hyprland.lua")

-- Change your own setup in these files (and overwrite any settings from defaults!)
source("~/.config/hypr/monitors.lua")
source("~/.config/hypr/workspaces.lua")
source("~/.config/hypr/input.lua")
source("~/.config/hypr/bindings.lua")
source("~/.config/hypr/envs.lua")
source("~/.config/hypr/autostart.lua")
source("~/.config/hypr/looknfeel.lua")
source("~/.config/hypr/windows.lua")
