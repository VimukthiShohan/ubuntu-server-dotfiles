-- Search keymaps: Telescope find + grep + search/replace

-- Find files - Community Convension
vim.keymap.set("n", "<leader>ff", function()
	require("telescope.builtin").find_files()
end, { desc = "Find files" })

-- Find files - My Convension
vim.keymap.set("n", "<leader><leader>", function()
	require("telescope.builtin").find_files()
end, { desc = "Find files" })

-- Git files
vim.keymap.set("n", "<leader>fg", function()
	require("telescope.builtin").git_files()
end, { desc = "Find git files" })

-- Grep word under cursor
vim.keymap.set("n", "<leader>fw", function()
	require("telescope.builtin").grep_string({ search = vim.fn.expand("<cword>") })
end, { desc = "Grep word under cursor" })

-- Grep WORD under cursor
vim.keymap.set("n", "<leader>fW", function()
	require("telescope.builtin").grep_string({ search = vim.fn.expand("<cWORD>") })
end, { desc = "Grep WORD under cursor" })

-- Grep search with input
vim.keymap.set("n", "<leader>fs", function()
	require("telescope.builtin").grep_string({ search = vim.fn.input("Grep > ") })
end, { desc = "Grep search" })

-- Grep with file filter
vim.keymap.set("n", "<leader>fS", function()
	local search = vim.fn.input("Grep > ")
	local pattern = vim.fn.input("File pattern (e.g. *.js) > ")
	local args = {}
	if pattern ~= "" then
		table.insert(args, "--glob")
		table.insert(args, pattern)
	end
	require("telescope.builtin").grep_string({
		search = search,
		additional_args = args,
	})
end, { desc = "Grep with file filter" })

-- Grep visual selection
vim.keymap.set("v", "<leader>fv", function()
	vim.cmd('normal! "vy')
	local text = vim.fn.getreg("v")
	require("telescope.builtin").grep_string({ search = text })
end, { desc = "Grep visual selection" })

-- Help tags
vim.keymap.set("n", "<leader>fh", function()
	require("telescope.builtin").help_tags()
end, { desc = "Help tags" })

-- Search/Replace
vim.keymap.set("n", "<leader>sr", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Replace word in file" })

-- Grep word and add to quickfix
vim.opt.grepprg = "rg -i --vimgrep --no-heading"
vim.keymap.set("n", "<leader>s*", ":grep<Space>", { desc = "Grep word (quickfix)" })
