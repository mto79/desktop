-- The web GUIs of what you are working on (desktop-guis): a browser profile of their own,
-- started with the class desktop-guis, so that every window of it is put on workspace 1
-- without being followed there. Ready when you look, never pulled in front of you.
hl.window_rule({ match = { class = "^(desktop-guis)$" }, workspace = "1 silent" })

-- Arriving on workspace 1, its GUI windows are made one group, a tab each (desktop-guis
-- arrange). Then and not before: Hyprland moves a window into a group only by focusing it,
-- which is fine once you are looking and would pull you there otherwise.
hl.on("workspace.active", function(workspace)
  if workspace and workspace.id == 1 then
    hl.exec_cmd("desktop-guis arrange")
  end
end)
