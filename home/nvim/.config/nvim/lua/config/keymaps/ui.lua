-- UI keymaps: Oil, wrap, undotree, animation, folds

-- Oil file explorer
vim.keymap.set("n", "<leader>e", function()
	require("oil").toggle_float()
end, { desc = "Toggle Oil file explorer" })

-- Wrap toggle
vim.keymap.set("n", "<leader>w", ":set wrap!<CR>", { desc = "Toggle wrap" })

-- Undotree
vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle, { desc = "Toggle undotree" })

-- Matrix rain animation
vim.keymap.set("n", "<leader>ar", function()
	require("cellular-automaton").start_animation("make_it_rain")
end, { desc = "Make it rain" })

vim.keymap.set("n", "zR", function()
	require("ufo").openAllFolds()
end, { desc = "Open all folds" })
vim.keymap.set("n", "zM", function()
	require("ufo").closeAllFolds()
end, { desc = "Close all folds" })