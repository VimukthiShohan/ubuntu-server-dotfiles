return {
	"stevearc/oil.nvim",
	---@module 'oil'
	---@type oil.SetupOpts
	opts = {},
	dependencies = { { "nvim-mini/mini.icons", opts = {} } },
	lazy = false,
	config = function()
		require("oil").setup({
			-- Configuration for the floating window
			float = {
				preview_split = "right", -- Forces preview to the right side
				padding = 2,
				border = "rounded",
			},
			-- Configuration for the preview window itself
			preview_win = {
				update_on_cursor_moved = true, -- Updates preview as you move
			},
			view_options = {
				show_hidden = true,
				is_hidden_file = function(name)
					return vim.startswith(name, ".")
				end,
			},
		})
	end,
}
