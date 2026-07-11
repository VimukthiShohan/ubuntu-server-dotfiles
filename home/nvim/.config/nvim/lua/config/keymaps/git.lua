-- Git keymaps: LazyGit + diff mode

-- LazyGit
vim.keymap.set("n", "<leader>gg", "<cmd>LazyGit<cr>", { desc = "LazyGit" })

-- Diff mode keymaps (buffer-local, only active in diff mode)
vim.api.nvim_create_autocmd("OptionSet", {
	pattern = "diff",
	callback = function()
		if vim.v.option_new then
			vim.keymap.set("n", "<leader>gl", "<cmd>diffget LOCAL<CR>", { buffer = true, desc = "Get from LOCAL" })
			vim.keymap.set("n", "<leader>gr", "<cmd>diffget REMOTE<CR>", { buffer = true, desc = "Get from REMOTE" })
		end
	end,
})