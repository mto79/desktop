-- Extra autostart processes
hl.on("hyprland.start", function()
  -- hl.exec_cmd("uwsm app -- my-service")

  -- start nm-applet at login
  hl.exec_cmd("nm-applet")

  -- Ducks whatever is playing while voxtype records. Follows voxtype's status stream, so
  -- it costs nothing while idle and needs no keybinding of its own.
  hl.exec_cmd("desktop-dictate watch")

  -- The starting workspaces -- which screen each sits on, and what opens on it. Placed by
  -- the script rather than by exec rules here; see the note in the script.
  hl.exec_cmd("desktop-workspace-start")
end)
