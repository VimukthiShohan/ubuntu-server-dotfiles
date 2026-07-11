return {
	{
		"nvim-treesitter/nvim-treesitter",
		version = false,
		branch = "main",
		build = ":TSUpdate",
		config = function()
			local parsers = {
				"javascript",
				"typescript",
				"vimdoc",
				"prisma",
				"jsdoc",
				"bash",
				"rust",
				"tsx",
				"jsx",
				"lua",
				"php",
				"nix",
				"go",
			}

			require("nvim-treesitter").setup({
				install_dir = vim.fn.stdpath("data") .. "/site",
				indent = { enable = true },
				highlight = {
					-- `false` will disable the whole extension
					enable = true,
					disable = function(lang, buf)
						if lang == "html" then
							print("disabled")
							return true
						end
						local max_filesize = 100 * 1024 -- 100 KB
						local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
						if ok and stats and stats.size > max_filesize then
							vim.notify(
								"File larger than 100KB treesitter disabled for performance",
								vim.log.levels.WARN,
								{ title = "Treesitter" }
							)
							return true
						end
					end,

					-- Setting this to true will run `:h syntax` and tree-sitter at the same time.
					-- Set this to `true` if you depend on "syntax" being enabled (like for indentation).
					-- Using this option may slow down your editor, and you may see some duplicate highlights.
					-- Instead of true it can also be a list of languages
					additional_vim_regex_highlighting = { "markdown" },
				},
			})
			if vim.fn.executable("tree-sitter") == 1 then
				require("nvim-treesitter").install(parsers)
			end

			vim.api.nvim_create_autocmd("FileType", {
				callback = function(args)
					local ft = vim.bo[args.buf].filetype
					local lang = vim.treesitter.language.get_lang(ft) or ft
					local ok = pcall(vim.treesitter.language.inspect, lang)

					if ok then
						vim.treesitter.start(args.buf, lang)
					end
				end,
			})

			vim.treesitter.language.register("templ", "templ")
		end,
	},

	{
		"nvim-treesitter/nvim-treesitter-context",
		after = "nvim-treesitter",
		-- ... rest of context config is fine ...
		config = function()
			require("treesitter-context").setup({
				enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
				multiwindow = false, -- Enable multiwindow support.
				max_lines = 0, -- How many lines the window should span. Values <= 0 mean no limit.
				min_window_height = 0, -- Minimum editor window height to enable context. Values <= 0 mean no limit.
				line_numbers = true,
				multiline_threshold = 20,
				trim_scope = "outer",
				mode = "cursor",
				separator = nil,
				zindex = 20,
				on_attach = nil,
			})
		end,
	},
}
