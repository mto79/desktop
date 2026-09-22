-- Menus
-- hl.bind("SUPER + SPACE", hl.dsp.exec_cmd('walker -p "Start…"'), { description = "Launch apps" })
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("desktop-shell shell toggleLauncher >/dev/null 2>&1 || desktop-menu apps"), { description = "Launch apps" })
-- hl.bind("SUPER + CTRL + E", hl.dsp.exec_cmd("walker -m Emojis"), { description = "Emoji picker" })
hl.bind("SUPER + ALT + SPACE", hl.dsp.exec_cmd("desktop-menu"), { description = "desktop menu" })
hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd("desktop-menu system"), { description = "Power menu" })
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("desktop-menu system"), { locked = true, description = "Power menu" })
hl.bind("SUPER + K", hl.dsp.exec_cmd("desktop-menu-keybindings"), { description = "Show key bindings" })
hl.bind("SUPER + M", hl.dsp.exec_cmd("desktop-shell shell togglePanel monitors >/dev/null 2>&1 || desktop-menu monitors"), { description = "Monitor layout" })
hl.bind("SUPER + A", hl.dsp.exec_cmd("desktop-agent-prompt"), { description = "Ask an agent" })
hl.bind("XF86Calculator", hl.dsp.exec_cmd("gnome-calculator"), { description = "Calculator" })

-- Aesthetics
hl.bind("SUPER + SHIFT + SPACE", hl.dsp.exec_cmd("desktop-toggle-bar"), { description = "Toggle top bar" })
hl.bind("SUPER + CTRL + SPACE", hl.dsp.exec_cmd("desktop-theme-bg-next"), { description = "Next background in theme" })
hl.bind("SUPER + SHIFT + CTRL + SPACE", hl.dsp.exec_cmd("desktop-menu theme"), { description = "Pick new theme" })
-- The active window's opacity rule, flipped in place. hyprland.conf reached it through
-- `hyprctl dispatch setprop "address:$(hyprctl activewindow -j | jq ...)"`, which a Lua
-- config no longer accepts; the dispatcher acts on the active window by itself.
hl.bind("SUPER + BACKSPACE", hl.dsp.window.set_prop({ prop = "opaque", value = "toggle" }), { description = "Toggle window transparency" })

-- Notifications
hl.bind("SUPER + COMMA", hl.dsp.exec_cmd("desktop-shell shell dismissNotification >/dev/null 2>&1 || makoctl dismiss"), { description = "Dismiss last notification" })
hl.bind("SUPER + SHIFT + COMMA", hl.dsp.exec_cmd("desktop-shell shell clearNotifications >/dev/null 2>&1 || makoctl dismiss --all"), { description = "Dismiss all notifications" })
hl.bind("SUPER + CTRL + COMMA", hl.dsp.exec_cmd("desktop-shell shell toggleDoNotDisturb >/dev/null 2>&1 || makoctl mode -t do-not-disturb"), { description = "Toggle silencing notifications" })

-- Toggle idling
hl.bind("SUPER + CTRL + I", hl.dsp.exec_cmd("desktop-toggle-idle"), { description = "Toggle locking on idle" })

-- Toggle nightlight
hl.bind("SUPER + CTRL + N", hl.dsp.exec_cmd("desktop-toggle-nightlight"), { description = "Toggle nightlight" })
-- Start capturing both sides of a call; the second press stops it and transcribes. The bar's
-- headset button does the same. M for meeting -- SUPER+M and SUPER ALT+M were taken.
hl.bind("SUPER + CTRL + M", hl.dsp.exec_cmd("desktop-meeting-capture toggle"), { description = "Toggle meeting capture" })

-- Screenshots
hl.bind("PRINT", hl.dsp.exec_cmd("desktop-cmd-screenshot"), { description = "Screenshot of region" })
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("desktop-cmd-screenshot window"), { description = "Screenshot of window" })
hl.bind("CTRL + PRINT", hl.dsp.exec_cmd("desktop-cmd-screenshot output"), { description = "Screenshot of display" })

-- Screen recordings
hl.bind("ALT + PRINT", hl.dsp.exec_cmd("desktop-cmd-screenrecord region"), { description = "Screen record a region" })
hl.bind("ALT + SHIFT + PRINT", hl.dsp.exec_cmd("desktop-cmd-screenrecord region audio"), { description = "Screen record a region with audio" })
hl.bind("CTRL + ALT + PRINT", hl.dsp.exec_cmd("desktop-cmd-screenrecord output"), { description = "Screen record display" })
hl.bind("CTRL + ALT + SHIFT + PRINT", hl.dsp.exec_cmd("desktop-cmd-screenrecord output audio"), { description = "Screen record display with audio" })

-- Color picker
hl.bind("SUPER + PRINT", hl.dsp.exec_cmd("pkill hyprpicker || hyprpicker -a"), { description = "Color picker" })

-- Waybar-less information
hl.bind("SUPER + CTRL + ALT + T", hl.dsp.exec_cmd('notify-send "    $(date +"%A %H:%M  —  %d %B W%V %Y")"'), { description = "Show time" })
hl.bind("SUPER + CTRL + ALT + B", hl.dsp.exec_cmd('notify-send "$(desktop-battery-status)"'), { description = "Show battery remaining" })

-- Shell panels. SUPER+D, then one letter.
--
-- A submap rather than seven chords because the free key space does not allow seven
-- guessable ones: SUPER+B is the browser, SUPER ALT+C is ChatGPT, SUPER ALT+M is
-- Mattermost, SUPER CTRL+N is the nightlight. A flat scheme would have handed three of
-- these a letter nobody would think of. In here every mnemonic is the real first letter.
--
-- Each letter is two binds, opening the panel and then leaving the submap, rather than
-- one Lua function doing both: desktop-shortcuts and desktop-menu-keybindings read the
-- command a key runs from `hyprctl binds`, and a function would hide it from them.
--
-- define_submap scopes its binds to the function, so the `submap = reset` hyprland.conf
-- could not do without -- or every bind sourced after would have landed in here -- is
-- gone, and cannot be forgotten.
hl.bind("SUPER + D", hl.dsp.submap("panels"), { description = "Panels" })
hl.define_submap("panels", function()
  hl.bind("A", hl.dsp.exec_cmd("desktop-shell shell togglePanel audio"), { description = "Audio panel" })
  hl.bind("A", hl.dsp.submap("reset"))
  hl.bind("I", hl.dsp.exec_cmd("desktop-shell shell togglePanel ai"), { description = "AI panel" })
  hl.bind("I", hl.dsp.submap("reset"))
  -- L for log the call: C is the CPU, M the memory.
  hl.bind("L", hl.dsp.exec_cmd("desktop-shell shell togglePanel capture"), { description = "Meeting capture panel" })
  hl.bind("L", hl.dsp.submap("reset"))
  -- F for filesystems: S is the backup panel.
  hl.bind("F", hl.dsp.exec_cmd("desktop-shell shell togglePanel storage"), { description = "Storage panel" })
  hl.bind("F", hl.dsp.submap("reset"))
  hl.bind("B", hl.dsp.exec_cmd("desktop-shell shell togglePanel bluetooth"), { description = "Bluetooth panel" })
  hl.bind("B", hl.dsp.submap("reset"))
  hl.bind("C", hl.dsp.exec_cmd("desktop-shell shell togglePanel cpu"), { description = "CPU panel" })
  hl.bind("C", hl.dsp.submap("reset"))
  -- E for energy: B is Bluetooth.
  hl.bind("E", hl.dsp.exec_cmd("desktop-shell shell togglePanel battery"), { description = "Battery panel" })
  hl.bind("E", hl.dsp.submap("reset"))
  hl.bind("D", hl.dsp.exec_cmd("desktop-shell shell togglePanel calendar"), { description = "Calendar panel" })
  hl.bind("D", hl.dsp.submap("reset"))
  -- G for grab the screen: R is the microphone, S the backup, V the VPN.
  hl.bind("G", hl.dsp.exec_cmd("desktop-shell shell togglePanel recording"), { description = "Screen recording panel" })
  hl.bind("G", hl.dsp.submap("reset"))
  hl.bind("M", hl.dsp.exec_cmd("desktop-shell shell togglePanel memory"), { description = "Memory panel" })
  hl.bind("M", hl.dsp.submap("reset"))
  hl.bind("N", hl.dsp.exec_cmd("desktop-shell shell togglePanel network"), { description = "Network panel" })
  hl.bind("N", hl.dsp.submap("reset"))
  hl.bind("P", hl.dsp.exec_cmd("desktop-shell shell togglePanel media"), { description = "Media panel" })
  hl.bind("P", hl.dsp.submap("reset"))
  -- R for record: M is the memory panel.
  hl.bind("R", hl.dsp.exec_cmd("desktop-shell shell togglePanel microphone"), { description = "Microphone panel" })
  hl.bind("R", hl.dsp.submap("reset"))
  hl.bind("S", hl.dsp.exec_cmd("desktop-shell shell togglePanel backup"), { description = "Backup panel" })
  hl.bind("S", hl.dsp.submap("reset"))
  -- T for talk: D is the calendar.
  hl.bind("T", hl.dsp.exec_cmd("desktop-shell shell togglePanel dictation"), { description = "Dictation panel" })
  hl.bind("T", hl.dsp.submap("reset"))
  hl.bind("U", hl.dsp.exec_cmd("desktop-shell shell togglePanel updates"), { description = "Updates panel" })
  hl.bind("U", hl.dsp.submap("reset"))
  hl.bind("V", hl.dsp.exec_cmd("desktop-shell shell togglePanel vpn"), { description = "VPN panel" })
  hl.bind("V", hl.dsp.submap("reset"))
  -- Y, since S is the backup panel and every letter of "security" is taken but Y.
  hl.bind("Y", hl.dsp.exec_cmd("desktop-shell shell togglePanel security"), { description = "Security panel" })
  hl.bind("Y", hl.dsp.submap("reset"))

  -- Any other key leaves, so a mistyped letter cannot strand you in a mode where the
  -- keyboard appears to do nothing.
  hl.bind("escape", hl.dsp.submap("reset"))
  hl.bind("catchall", hl.dsp.submap("reset"))
end)
