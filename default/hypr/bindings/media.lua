-- Laptop multimedia keys for volume and LCD brightness.
--
-- No notify-send here any more: the shell's OSD watches PipeWire, so volume and mute
-- draw themselves however they were changed -- a key, the audio panel, a scroll on the
-- bar, another application. Brightness has no such bus, so desktop-brightness announces
-- itself over IPC and falls back to a notification when the shell is not running.
--
-- It also picks which backlight to move, which bare brightnessctl does not: that takes
-- the first one it finds, and on a hybrid laptop the discrete GPU exposes one for an
-- output nothing is plugged into. See the script.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 0.05+"), { locked = true, description = "Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05-"), { locked = true, description = "Volume down" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, description = "Mute" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, description = "Mute microphone" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("desktop-brightness up"), { locked = true, description = "Brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("desktop-brightness down"), { locked = true, description = "Brightness down" })

-- Requires playerctl
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl pause"), { locked = true, description = "Pause" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Next" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Previous" })

-- Switch audio output with Super + Mute
hl.bind("SUPER + XF86AudioMute", hl.dsp.exec_cmd("desktop-cmd-audio-switch"), { locked = true, description = "Switch audio output" })
