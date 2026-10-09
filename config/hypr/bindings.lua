-- Application bindings
local terminal = "uwsm app -- $TERMINAL"
local passwordmanager = "~/.local/bin/KeePassXC.AppImage"

hl.bind("SUPER + return", hl.dsp.exec_cmd(terminal .. ' --working-directory="$(desktop-cmd-terminal-cwd)"'), { description = "Terminal" })
hl.bind("SUPER + E", hl.dsp.exec_cmd("uwsm app -- nautilus --new-window"), { description = "File Explorer" })
hl.bind("SUPER + B", hl.dsp.exec_cmd("desktop-launch-browser"), { description = "Browser" })
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("desktop-launch-browser --private"), { description = "Browser (private)" })
hl.bind("SUPER + X", hl.dsp.exec_cmd("desktop-launch-or-focus KeePassXC " .. passwordmanager), { description = "Password Manager" })
hl.bind("SUPER + N", hl.dsp.exec_cmd(terminal .. " -e nvim"), { description = "Neovim" })
hl.bind("SUPER + T", hl.dsp.exec_cmd(terminal .. " -e btop"), { description = "Activity" })

-- Push-to-talk is Right Alt, and it is not bound here: voxtype reads the key device
-- itself, which is the only way the release is never missed. A `bindr` on a chord dropped
-- about one release in three -- it fires only while the modifiers still match -- and a
-- recording nobody stopped ran to its cap and came back with invented words.
-- See bin/desktop-dictate, which ducks the music by following voxtype's state.

-- A # in a web app URL needs no doubling here, as it did in hyprland.conf: in Lua it is
-- only ever part of the string.
hl.bind("SUPER + ALT + C", hl.dsp.exec_cmd('desktop-launch-webapp "https://chatgpt.com"'), { description = "ChatGPT" })
hl.bind("SUPER + ALT + M", hl.dsp.exec_cmd('desktop-launch-webapp "https://chat.nationaalarchief.nl"'), { description = "Mattermost" })
hl.bind("SUPER + ALT + T", hl.dsp.exec_cmd('desktop-launch-webapp "https://teams.microsoft.com"'), { description = "Teams" })

-- Unbind and remap defaults
hl.unbind("SUPER + W")
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Close active window" })
hl.unbind("SUPER + J")
hl.bind("SUPER + S", hl.dsp.layout("togglesplit"), { description = "Toggle split" })
hl.unbind("SUPER + V")
hl.bind("SUPER + F", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })
hl.bind("SUPER + V", hl.dsp.exec_cmd("desktop-clipboard pick"), { description = "Clipboard history" })
hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("desktop-clipboard delete"), { description = "Forget a clipboard entry" })
hl.unbind("SUPER + K")
hl.bind("SUPER + CTRL + K", hl.dsp.exec_cmd("~/.local/share/desktop/bin/desktop-menu-keybindings"), { description = "Show key bindings" })
hl.bind("SUPER + CTRL + R", hl.dsp.exec_cmd("desktop-restart-shell"), { description = "Reload desktop shell" })

-- Move focus with vim keys
hl.bind("SUPER + H", hl.dsp.focus({ direction = "left" }), { description = "Move focus left" })
hl.bind("SUPER + L", hl.dsp.focus({ direction = "right" }), { description = "Move focus right" })
hl.bind("SUPER + K", hl.dsp.focus({ direction = "up" }), { description = "Move focus up" })
hl.bind("SUPER + J", hl.dsp.focus({ direction = "down" }), { description = "Move focus down" })

-- Swap active window with vim keys
hl.bind("SUPER + SHIFT + H", hl.dsp.window.swap({ direction = "left" }), { description = "Swap window to the left" })
hl.bind("SUPER + SHIFT + L", hl.dsp.window.swap({ direction = "right" }), { description = "Swap window to the right" })
hl.bind("SUPER + SHIFT + K", hl.dsp.window.swap({ direction = "up" }), { description = "Swap window up" })
hl.bind("SUPER + SHIFT + J", hl.dsp.window.swap({ direction = "down" }), { description = "Swap window down" })
