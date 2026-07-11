return {
	"nvim-telescope/telescope.nvim",

	tag = "v0.2.0",

	dependencies = {
		"nvim-lua/plenary.nvim",
        -- optional but recommended
        { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
	},

	config = function()
		require("telescope").setup({
			defaults = {
				hidden = true,
				file_ignore_patterns = {
					"^.git/",
				},
			},
			pickers = {
				find_files = {
					hidden = true,
				},
			},
		})
	end,
}
