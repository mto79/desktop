-- Fewer wakeups from an editor nobody is typing in.
--
-- Every repository's tmux session keeps an nvim open, twenty-odd at a time, and an idle
-- one woke a hundred times a second: lualine checks its redraw queue every 16ms whether
-- or not anything is queued, and snacks empties its statuscolumn cache every 50ms. Across
-- all of them that was a quarter of a core spent on nothing.
--
-- 50ms is still faster than the eye follows a statusline; a sign appears within a quarter
-- of a second. which-key polls every 50ms too, but that is hardcoded in the plugin.
return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.options = opts.options or {}
      opts.options.refresh = vim.tbl_extend("force", opts.options.refresh or {}, { refresh_time = 50 })
    end,
  },
  {
    "folke/snacks.nvim",
    opts = { statuscolumn = { refresh = 250 } },
  },
}
