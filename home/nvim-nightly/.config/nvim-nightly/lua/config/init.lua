require("config.set")
require("config.remap")
require("config.lazy_init")

local augroup = vim.api.nvim_create_augroup
local AlphaGroup = augroup("Alpha", { clear = true })

local autocmd = vim.api.nvim_create_autocmd
local yank_group = augroup("HighlightYank", { clear = true })

function R(name)
	require("plenary.reload").reload_module(name)
end

vim.filetype.add({
	extension = {
		templ = "templ",
	},
})

-- Shorten the :verbose command to :V
vim.api.nvim_create_user_command("V", function(ctx)
	vim.cmd(ctx.args .. "verbose")
end, {
	nargs = "*",
	complete = "command",
})

--------------------
--- CUSTOM MACROs---
--------------------
--- JsLogMacro ---
local esc = vim.api.nvim_replace_termcodes("<Esc>", true, true, true)

autocmd("FileType", {
	group = AlphaGroup,
	pattern = { "javascript", "typescript" },
	callback = function()
		local macro = "mz" .. "yiw" .. "oconsole.log('" .. esc .. "p" .. "a : ', " .. esc .. "p" .. "A);" .. esc .. "`z"

		vim.fn.setreg("l", macro)
		vim.keymap.set("n", "<leader>gl", "@l", { buffer = true, desc = "console.log(word under cursor)" })
	end,
})

-- Handle `opencode` events
autocmd("User", {
	group = AlphaGroup,
	pattern = "OpencodeEvent:*", -- Optionally filter event types
	callback = function(args)
		---@type opencode.cli.client.Event
		local event = args.data.event

		-- See the available event types and their properties
		vim.notify(vim.inspect(event))
		-- Do something useful
		if event.type == "session.idle" then
			vim.notify("`opencode` finished responding")
		end
	end,
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

autocmd({ "BufWritePre" }, {
	group = AlphaGroup,
	pattern = "*",
	command = [[%s/\s\+$//e]],
})

autocmd({ "BufRead", "BufNewFile" }, {
	pattern = { ".env", ".env.*", "*.env", "*.env.*" },
	callback = function()
		vim.bo.filetype = "sh"
	end,
})

autocmd("LspAttach", {
	group = AlphaGroup,
	callback = function(e)
		local opts = { buffer = e.buf }
		vim.keymap.set("n", "gd", function()
			vim.lsp.buf.definition()
		end, opts)
		vim.keymap.set("n", "K", function()
			vim.lsp.buf.hover()
		end, opts)
		vim.keymap.set("n", "<leader>vws", function()
			vim.lsp.buf.workspace_symbol()
		end, opts)
		vim.keymap.set("n", "<leader>vd", function()
			vim.diagnostic.open_float()
		end, opts)
		vim.keymap.set("n", "<leader>vca", function()
			vim.lsp.buf.code_action()
		end, opts)
		vim.keymap.set("n", "<leader>vrr", function()
			vim.lsp.buf.referencrs()
		end, opts)
		vim.keymap.set("n", "<leader>vrn", function()
			vim.lsp.buf.rename()
		end, opts)
		vim.keymap.set("i", "<C-h>", function()
			vim.lsp.buf.signature_help()
		end, opts)
		vim.keymap.set("n", "[d", function()
			vim.diagnostic.jump({ count = 1, float = true })
		end, opts)
		vim.keymap.set("n", "]d", function()
			vim.diagnostic.jump({ count = -1, float = true })
		end, opts)
	end,
})
