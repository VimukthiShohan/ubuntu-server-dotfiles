-- General keymaps: non-leader keys, scroll, join, increment, delete

-- Exit to normal mode, auto format the current file, and write all
vim.keymap.set({ "n", "i" }, "<C-s>", function()
	vim.cmd("stopinsert")
	require("conform").format({ bufnr = 0 })
	vim.cmd("wa")
end, { desc = "Save, format, and write all" })

-- Save & Quit shortcut (ctrl + s)
vim.keymap.set("n", "<C-q>", ":wqa<CR>", { desc = "Save and quit all" })
vim.keymap.set("n", "<C-w>", ":q<CR>", { desc = "Close window" })

-- Move the selected lines up and down | shift + j = ↑ | shift + k = ↓
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Join lines below to the current line preserving the cursor in the same place
vim.keymap.set("n", "J", "mzJ`z", { desc = "Join lines" })

-- Centered scrolling and search
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Half-page down centered" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Half-page up centered" })
vim.keymap.set("n", "n", "nzzzv", { desc = "Next search result centered" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Previous search result centered" })

-- Paste the copied value without copying the replacing value to clipboard
vim.keymap.set("x", "p", [["_dP]], { desc = "Paste without yanking" })

-- Delete to black hole register (must be followed by a vim motion in normal mode)
vim.keymap.set({ "n", "v" }, "<leader>d", '"_d', { desc = "Delete to black hole register" })

-- Disable Ex Mode
vim.keymap.set("n", "Q", "<nop>", { desc = "Disable Ex mode" })

-- Remap increment and decrement
vim.keymap.set("n", "+", "<C-a>", { desc = "Increment under cursor" })
vim.keymap.set("n", "-", "<C-x>", { desc = "Decrement under cursor" })