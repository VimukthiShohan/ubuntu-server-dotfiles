function ColorMyPencils(color)
	color = color or "tokyonight-night"
	-- color = color or "github_dark_high_contrast"
	vim.cmd.colorscheme(color)
end

return {
	{
		"folke/tokyonight.nvim",
		lazy = false,
		priority = 1000,
		opts = {},
	},
	{
		"projekt0n/github-nvim-theme",
		name = "github-theme",
		config = function()
			ColorMyPencils()
		end,
	},
}
