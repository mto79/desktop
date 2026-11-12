-- Define terminal tag to style them uniformly
hl.window_rule({ match = { class = "(com.mitchellh.ghostty)" }, tag = "+terminal" })

-- The agent console, SUPER + ~ (desktop-agent-console): on a special workspace of its
-- own, so it appears over whatever workspace is showing and hides without stopping.
-- Floating, wide and short, hanging from the top of the screen.
local console = { class = "^(com\\.mitchellh\\.ghostty)$", initial_title = "^(Console)$" }
hl.window_rule({ match = console, workspace = "special:console" })
hl.window_rule({ match = console, float = true })
hl.window_rule({ match = console, size = { "monitor_w*0.8", "monitor_h*0.6" } })
hl.window_rule({ match = console, move = { "monitor_w*0.1", "monitor_h*0.04" } })
