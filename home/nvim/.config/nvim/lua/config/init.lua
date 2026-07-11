require("config.set")
require("config.lazy_init")
require("config.keymaps")

local augroup = vim.api.nvim_create_augroup
local AlphaGroup = augroup("Alpha", { clear = true })

local autocmd = vim.api.nvim_create_autocmd
local yank_group = augroup("HighlightYank", { clear = true })

function R(name)
	require("plenary.reload").reload_module(name)
end

vim.filetype.add({
	extension = {
		prisma = "prisma",
		templ = "templ",
	},
	filename = {
		[".prisma"] = "prisma",
	},
})

-- Shorten the :verbose command to :V
vim.api.nvim_create_user_command("V", function(ctx)
	vim.cmd(ctx.args .. "verbose")
end, {
	nargs = "*",
	complete = "command",
})

-- Highlight the yanked code segment
autocmd("TextYankPost", {
	group = yank_group,
	pattern = "*",
	callback = function()
		vim.highlight.on_yank({
			higroup = "IncSearch",
			timeout = 40,
		})
	end,
})

-- Strip trailing whitespace on save
autocmd({ "BufWritePre" }, {
	group = AlphaGroup,
	pattern = "*",
	command = [[%s/\s\+$//e]],
})

-- Set env files to sh filetype
autocmd({ "BufRead", "BufNewFile" }, {
	pattern = { ".env", ".env.*", "*.env", "*.env.*" },
	callback = function()
		vim.bo.filetype = "sh"
	end,
})

-- Auto-enable wrap for Markdown files
autocmd("FileType", {
	group = AlphaGroup,
	pattern = "markdown",
	callback = function()
		vim.opt_local.wrap = true
	end,
})
