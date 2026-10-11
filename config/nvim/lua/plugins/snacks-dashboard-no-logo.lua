return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      -- The start screen without the LazyVim logo. The logo is the "header" section, and
      -- snacks draws whichever sections are listed -- so leaving it out here, in our own
      -- spec, removes it without touching LazyVim's files, which an update would restore.
      sections = {
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      },
    },
  },
}
