hl.config({ general = { col = { active_border = "rgb(c6d0f5)" } } })

-- Grouped windows' tabs, as tmux marks its own: the one on show in the accent with the dark
-- base for its text, the rest the bar's pill with muted text.
hl.config({ group = {
  col = { border_active = "rgb(89b4fa)", border_inactive = "rgb(313244)" },
  groupbar = {
    col = { active = "rgb(89b4fa)", inactive = "rgb(1e1e2e)" },
    text_color = "rgb(1e1e2e)",
    text_color_inactive = "rgb(7f849c)",
  },
} })
