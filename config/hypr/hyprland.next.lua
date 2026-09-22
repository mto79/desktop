-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/
--
-- The Lua twin of hyprland.conf, file for file, for Hyprland 0.57, which reads no other.
--
-- Named hyprland.next.lua until the switch, because the name is the switch: Hyprland reads
-- hyprland.lua in place of hyprland.conf whenever one exists, deciding once at startup,
-- and install/config/config.sh copies all of config/ into ~/.config. Under its real name
-- this would take over a fresh install before the scripts and the bar speak the Lua
-- dispatchers. Renamed to hyprland.lua when they do; until then test/hypr-lua-test.sh
-- loads it with Hyprland --verify-config. After the switch, removing hyprland.lua and
-- logging in again is the way back, for as long as the .conf files are kept.

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
