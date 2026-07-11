-- Opencode/AI keymaps

-- Ask opencode
vim.keymap.set({ "n", "x" }, "<leader>oa", function()
	require("opencode").ask("@this: ", { submit = true })
end, { desc = "Ask opencode" })

-- Execute opencode action
vim.keymap.set({ "n", "x" }, "<leader>os", function()
	require("opencode").select()
end, { desc = "Execute opencode action" })

-- Toggle opencode
vim.keymap.set({ "n", "t" }, "<leader>ot", function()
	require("opencode").toggle()
end, { desc = "Toggle opencode" })

-- Add range to opencode
vim.keymap.set({ "n", "x" }, "<leader>oo", function()
	return require("opencode").operator("@this ")
end, { desc = "Add range to opencode", expr = true })

-- Add line to opencode
vim.keymap.set("n", "<leader>ol", function()
	return require("opencode").operator("@this ") .. "_"
end, { desc = "Add line to opencode", expr = true })
