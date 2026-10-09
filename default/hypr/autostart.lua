-- What starts with the session. Lua's counterpart of exec-once: a hyprland.start handler.
hl.on("hyprland.start", function()
  hl.exec_cmd("uwsm app -- hypridle")
  -- Replaced by the shell's own notification server; one process owns the bus name, and
  -- desktop-launch-shell starts mako again if the shell will not stay up.
  -- hl.exec_cmd("uwsm app -- mako")
  -- Replaced by the Quickshell desktop shell; kept as a fallback (see desktop-launch-shell).
  -- hl.exec_cmd("uwsm app -- waybar")
  hl.exec_cmd("uwsm app -- desktop-launch-shell")
  hl.exec_cmd("uwsm app -- fcitx5")
  hl.exec_cmd("uwsm app -- swaybg -i ~/.config/desktop/current/background -m fill")
  -- hl.exec_cmd("uwsm app -- swayosd-server")
  hl.exec_cmd("systemctl --user enable --now hyprpolkitagent.service")

  -- Screens come and go -- docking at a desk, unplugging to leave -- and the layout should
  -- follow them without being asked. SUPER+M stays the way to overrule the choice, not the
  -- way to make it. Applies the matching layout once at login too.
  hl.exec_cmd("uwsm app -- desktop-monitors-watch")

  -- Clipboard history: keeps what is copied, text and images, so SUPER+V can offer it
  -- again. Leaves alone whatever a password manager copies -- see desktop-clipboard.
  hl.exec_cmd("uwsm app -- desktop-clipboard watch")
end)
