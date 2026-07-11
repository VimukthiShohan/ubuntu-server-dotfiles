-- Set the leader key to space
vim.g.mapleader = " "

-- Load all keymap modules (use pcall so missing modules don't break startup)
local keymaps = {
	"general",
	"git",
	"search",
	"lsp",
	"diagnostics",
	"quickfix",
	"ai",
	"navigation",
	"editor",
	"ui",
	"buffer",
	"markdown",
}

for _, name in ipairs(keymaps) do
	local ok, err = pcall(require, "config.keymaps." .. name)
	if not ok then
		vim.notify_once("keymaps." .. name .. " not loaded: " .. err, vim.log.levels.WARN)
	end
end