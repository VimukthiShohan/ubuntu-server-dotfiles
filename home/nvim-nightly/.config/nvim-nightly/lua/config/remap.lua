-- Set the leader key to space
vim.g.mapleader = " "

-- Open default file explorer
-- vim.keymap.set("n", "<leader>e", '[[<cmd>lua require("oil").toggle_float()<CR>]]', { desc = "Open parent directory" })

-- Exit to normal mode, auto format the current file, and write all
vim.keymap.set({ "n", "i" }, "<C-s>", function()
	vim.cmd("stopinsert")
	require("conform").format({ bufnr = 0 })
	vim.cmd("wa")
end)

-- Save & Quit shortcut (ctrl + s)
vim.keymap.set("n", "<C-q>", ":wqa<CR>", { desc = "Save file and quit vim" })
vim.keymap.set("n", "<C-x>", ":q<CR>", { desc = "Close current buffer" })

-- Move the selected lines up and down | shift + j = ↑ | shift + k = ↓
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Switch between tabs
vim.keymap.set("n", "<S-l>", "<CMD>tabn<CR>")
vim.keymap.set("n", "<S-h>", "<CMD>tabp<CR>")

-- Close current buffer
vim.keymap.set("n", "<leader>bd", "<CMD>:q<CR>")

-- Join lines bellow to the current line preserving the cursor in the same place
vim.keymap.set("n", "J", "mzJ`z")

-- Centered scrolloing and search
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- Paste the copied value without coping the replacing value to clipboard
vim.keymap.set("x", "p", [["_dP]])

-- Delete the texts without copying those to clipboard (must be followed by a vim motion in the normal mode)
vim.keymap.set({ "n", "v" }, "<leader>d", '"_d')

-- Disable Ex Mode
vim.keymap.set("n", "Q", "<nop>")

-- Quickfix list open/close toggle
local function toggle_quickfix()
	-- If any quickfix window exists in current tabpage, close it
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].buftype == "quickfix" then
			vim.cmd("cclose")
			return
		end
	end

	-- Otherwise open it (only if there are items; optional)
	local qf = vim.fn.getqflist()
	if #qf == 0 then
		vim.notify("Quickfix list is empty", vim.log.levels.INFO)
		return
	end
	vim.cmd("copen")
end

-- Location list open/close toggle
local function toggle_loclist()
	-- If any location-list window exists in current tabpage, close it
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].buftype == "quickfix" and vim.fn.getwininfo(win)[1].loclist == 1 then
			vim.cmd("lclose")
			return
		end
	end

	-- Otherwise open it (only if there are items; optional)
	local loc = vim.fn.getloclist(0) -- 0 = current window
	if #loc == 0 then
		vim.notify("Location list is empty", vim.log.levels.INFO)
		return
	end
	vim.cmd("lopen")
end

-- Quickfix list handling
vim.keymap.set("n", "<M-q>", toggle_quickfix)
vim.keymap.set("n", "<M-j>", "<cmd>cnext<CR>zz")
vim.keymap.set("n", "<M-k>", "<cmd>cprev<CR>zz")

-- Location list handling
vim.keymap.set("n", "<M-l>", toggle_loclist)
vim.keymap.set("n", "<leader>j", "<cmd>lnext<CR>zz")
vim.keymap.set("n", "<leader>k", "<cmd>lprev<CR>zz")

-- Find & Replace every occurrence of current word
vim.keymap.set("n", "<leader>r", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

-- Add execution permission to current file
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

vim.keymap.set("n", "<leader>rain", function()
	require("cellular-automaton").start_animation("make_it_rain")
end)

vim.cmd(":hi statusline guibg=NONE")
