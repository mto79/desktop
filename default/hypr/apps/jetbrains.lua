-- Fixing popup size issue
hl.window_rule({ match = { class = "(.*jetbrains.*)$", title = "^$", float = true }, size = { "50%", "50%" } })

-- Fix tab dragging (always have a single space character as their title)
--
-- Carried over exactly from jetbrains.conf, where the title was written ^\\s$: hyprlang
-- does not unescape, so that regex is a backslash and an s, not a space, and these two
-- rules have likely never matched. Kept as they were so the conversion changes nothing;
-- "^\\s$" here is what the comment means, if the tab-dragging fix turns out to be needed.
hl.window_rule({ match = { class = "^(.*jetbrains.*)$", title = "^\\\\s$" }, no_initial_focus = true })
hl.window_rule({ match = { class = "^(.*jetbrains.*)$", title = "^\\\\s$" }, no_focus = true })
