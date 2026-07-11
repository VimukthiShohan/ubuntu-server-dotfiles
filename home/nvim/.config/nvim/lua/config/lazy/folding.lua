return {
	{
		"kevinhwang91/promise-async",
		lazy = true,
	},
	{
		"kevinhwang91/nvim-ufo",
		event = { "BufReadPost", "BufNewFile" },
		dependencies = {
			"kevinhwang91/promise-async",
		},
		config = function()
			local function provider_selector(_, filetype, buftype)
				if buftype ~= "" then
					return { "indent" }
				end

				local lang = vim.treesitter.language.get_lang(filetype) or filetype
				local has_parser = pcall(vim.treesitter.language.inspect, lang)

				if has_parser then
					return { "treesitter", "indent" }
				end

				return { "lsp", "indent" }
			end

			local function fold_virt_text_handler(virt_text, lnum, end_lnum, width, truncate)
				local new_virt_text = {}
				local hidden_line_count = end_lnum - lnum
				local suffix = string.format("  { ... %d lines ... }", hidden_line_count)
				local suffix_width = vim.fn.strdisplaywidth(suffix)
				local target_width = width - suffix_width
				local current_width = 0

				for _, chunk in ipairs(virt_text) do
					local chunk_text = chunk[1]
					local chunk_width = vim.fn.strdisplaywidth(chunk_text)

					if current_width + chunk_width < target_width then
						table.insert(new_virt_text, chunk)
					else
						chunk_text = truncate(chunk_text, math.max(target_width - current_width, 0))
						table.insert(new_virt_text, { chunk_text, chunk[2] })
						chunk_width = vim.fn.strdisplaywidth(chunk_text)

						if current_width + chunk_width < target_width then
							suffix = suffix .. string.rep(" ", target_width - current_width - chunk_width)
						end

						break
					end

					current_width = current_width + chunk_width
				end

				table.insert(new_virt_text, { suffix, "Comment" })
				return new_virt_text
			end

			require("ufo").setup({
				provider_selector = provider_selector,
				close_fold_kinds_for_ft = {
					default = {},
				},
				close_fold_current_line_for_ft = {
					default = false,
				},
				fold_virt_text_handler = fold_virt_text_handler,
			})
		end,
	},
}
