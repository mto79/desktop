-- Add custom window config in this file.

-- KeePassXC and Obsidian are AppImages, and each re-execs into its own systemd scope:
-- the process Hyprland spawns is not the one that ends up owning the window, so an exec
-- rule placing it on a workspace has nothing to match. desktop-workspace-start places
-- them at login; matching the window's own class keeps them there when opened later.
hl.window_rule({ match = { class = "^(org\\.keepassxc\\.KeePassXC)$" }, workspace = "4 silent" })
hl.window_rule({ match = { class = "^(md\\.obsidian\\.Obsidian)$" }, workspace = "5 silent" })

-- The polkit agent's dialog maps floating but never asks for focus, and it does not
-- always land on the workspace you are looking at -- it opened on workspace 2 while the
-- focus sat on workspace 3, so no keystroke ever reached the password field and the
-- Authenticate button stayed disabled. Pinning makes it follow you to the visible
-- workspace; stay_focused is what actually hands it the keyboard.
hl.window_rule({ match = { class = "^(hyprpolkitagent)$" }, float = true })
hl.window_rule({ match = { class = "^(hyprpolkitagent)$" }, center = true })
hl.window_rule({ match = { class = "^(hyprpolkitagent)$" }, pin = true })
hl.window_rule({ match = { class = "^(hyprpolkitagent)$" }, stay_focused = true })
