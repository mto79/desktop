hl.config({ general = { col = { active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 } } } })

-- Grouped windows' tabs, as tmux marks its own: the one on show in the accent with the dark
-- base for its text, the rest the bar's pill with muted text.
hl.config({ group = {
  col = { border_active = "rgb(7aa2f7)", border_inactive = "rgb(24263a)" },
  groupbar = {
    col = { active = "rgb(7aa2f7)", inactive = "rgb(1a1b2a)" },
    text_color = "rgb(1a1b26)",
    text_color_inactive = "rgb(565f89)",
  },
} })
