hl.config({ general = { col = { active_border = "rgb(D8DEE9)" } } })

-- Grouped windows' tabs, as tmux marks its own: the one on show in the accent with the dark
-- base for its text, the rest the bar's pill with muted text.
hl.config({ group = {
  col = { border_active = "rgb(81a1c1)", border_inactive = "rgb(434c5e)" },
  groupbar = {
    col = { active = "rgb(81a1c1)", inactive = "rgb(3b4252)" },
    text_color = "rgb(2e3440)",
    text_color_inactive = "rgb(4c566a)",
  },
} })
