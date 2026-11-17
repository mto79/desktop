-- The web GUIs of what you are working on (desktop-guis): a browser profile of their own,
-- started with the class desktop-guis, so that every window of it is put on workspace 1
-- without being followed there. Ready when you look, never pulled in front of you.
hl.window_rule({ match = { class = "^(desktop-guis)$" }, workspace = "1 silent" })
