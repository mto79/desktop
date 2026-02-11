return {
  "folke/snacks.nvim",
  opts = {
    scroll = {
      enabled = false, -- Disable scrolling animations
    },
    picker = {
      sources = {
        explorer = {
          hidden = true, -- Show hidden files (dotfiles)
          ignored = true, -- Show git-ignored files (e.g., node_modules)
        },
      },
    },
  },
}
