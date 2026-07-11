-- Navigation keymaps: Harpoon

vim.keymap.set("n", "<leader>ha", function()
	require("harpoon"):list():add()
end, { desc = "Add to harpoon" })

vim.keymap.set("n", "<leader>he", function()
	require("harpoon").ui:toggle_quick_menu(require("harpoon"):list())
end, { desc = "Toggle harpoon menu" })

for i = 1, 9 do
	vim.keymap.set("n", "<leader>h" .. i, function()
		require("harpoon"):list():select(i)
	end, { desc = "Harpoon " .. i })
end

vim.keymap.set("n", "<S-h>", function()
	require("harpoon"):list():prev()
end, { desc = "Previous harpoon" })
vim.keymap.set("n", "<S-l>", function()
	require("harpoon"):list():next()
end, { desc = "Next harpoon" })