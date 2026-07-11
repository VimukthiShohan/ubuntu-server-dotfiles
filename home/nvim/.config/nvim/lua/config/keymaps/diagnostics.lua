-- Diagnostics keymaps: Trouble + diagnostic navigation

-- Toggle Trouble diagnostics
vim.keymap.set("n", "<leader>dd", function()
	require("trouble").toggle("diagnostics")
end, { desc = "Toggle Trouble" })

-- Diagnostic float
vim.keymap.set("n", "<leader>de", vim.diagnostic.open_float, { desc = "Diagnostic float" })

-- Diagnostic navigation
vim.keymap.set("n", "[d", function()
	vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })

vim.keymap.set("n", "]d", function()
	vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })

-- Trouble navigation
vim.keymap.set("n", "[t", function()
	require("trouble").next({ skip_groups = true, jump = true })
end, { desc = "Next Trouble item" })

vim.keymap.set("n", "]t", function()
	require("trouble").prev({ skip_groups = true, jump = true })
end, { desc = "Previous Trouble item" })