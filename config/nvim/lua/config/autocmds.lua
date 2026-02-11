vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    -- only when starting nvim without files
    if vim.fn.argc() == 0 then
      require("snacks").explorer()
    end
  end,
})
