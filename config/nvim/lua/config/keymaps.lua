-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Compare the current file with another, side by side in a vertical split.
--
--   <leader>fd      pick the other file, as <leader>ff would, and diff the two
--   <leader>fD      stop comparing, and close the file that was opened for it
--   :Compare [file] the same from the command line, with the path completed
--
-- It is Neovim's own diff mode, so its keys work: ]c / [c jump between changes, do takes
-- a change from the other side, dp puts one there.

local compare_win

local function compare_with(path)
  vim.cmd("vertical diffsplit " .. vim.fn.fnameescape(path))
  compare_win = vim.api.nvim_get_current_win()
  -- Back to the file you started from, so the cursor stays where you were working.
  vim.cmd("wincmd p")
end

vim.api.nvim_create_user_command("Compare", function(opts)
  if opts.args ~= "" then
    return compare_with(opts.args)
  end
  Snacks.picker.files({
    title = "Compare with",
    confirm = function(picker, item)
      picker:close()
      if item then
        compare_with(Snacks.picker.util.path(item))
      end
    end,
  })
end, { nargs = "?", complete = "file", desc = "Compare this file with another" })

vim.keymap.set("n", "<leader>fd", "<cmd>Compare<cr>", { desc = "Compare with file (diff)" })

vim.keymap.set("n", "<leader>fD", function()
  vim.cmd("diffoff!")
  if compare_win and vim.api.nvim_win_is_valid(compare_win) then
    vim.api.nvim_win_close(compare_win, false)
  end
  compare_win = nil
end, { desc = "Stop comparing" })
