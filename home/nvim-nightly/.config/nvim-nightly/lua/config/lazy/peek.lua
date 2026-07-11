return {
	"toppair/peek.nvim",
	event = { "VeryLazy" },
	build = "deno task --quiet build:fast",
	config = function()
		require("peek").setup({
			app = "zen",
		})

		vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
		vim.keymap.set("n", "mo", function()
			require("peek").open()
		end)
		vim.keymap.set("n", "mc", function()
			require("peek").close()
		end)
	end,
}
