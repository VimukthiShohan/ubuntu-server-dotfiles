-- Quickfix and Location list keymaps

local function toggle_quickfix()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].buftype == "quickfix" then
			vim.cmd("cclose")
			return
		end
	end

	local qf = vim.fn.getqflist()
	if #qf == 0 then
		vim.notify("Quickfix list is empty", vim.log.levels.INFO)
		return
	end
	vim.cmd("copen")
end

local function toggle_loclist()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].buftype == "quickfix" and vim.fn.getwininfo(win)[1].loclist == 1 then
			vim.cmd("lclose")
			return
		end
	end

	local loc = vim.fn.getloclist(0)
	if #loc == 0 then
		vim.notify("Location list is empty", vim.log.levels.INFO)
		return
	end
	vim.cmd("lopen")
end

-- Quickfix
vim.keymap.set("n", "<leader>qq", toggle_quickfix, { desc = "Toggle quickfix" })
vim.keymap.set("n", "<M-j>", "<cmd>cnext<CR>zz", { desc = "Next quickfix" })
vim.keymap.set("n", "<M-k>", "<cmd>cprev<CR>zz", { desc = "Previous quickfix" })

-- Location list
vim.keymap.set("n", "<leader>ql", toggle_loclist, { desc = "Toggle location list" })
vim.keymap.set("n", "<leader>qN", "<cmd>lnext<CR>zz", { desc = "Next location" })
vim.keymap.set("n", "<leader>qP", "<cmd>lprev<CR>zz", { desc = "Previous location" })
