return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local harpoon = require("harpoon")
		harpoon.setup()

		-- Add current file to harpoon menu
		vim.keymap.set("n", "<leader>ha", function()
			harpoon:list():add()
		end)

		vim.keymap.set("n", "<leader>hd", function()
			harpoon:list():add()
		end)

		-- Toggle harpoon buffer menu
		vim.keymap.set("n", "<leader>he", function()
			harpoon.ui:toggle_quick_menu(harpoon:list())
		end)

		-- Open specific harpoon buffer
		vim.keymap.set("n", "<leader>h1", function()
			harpoon:list():select(1)
		end)
		vim.keymap.set("n", "<leader>h2", function()
			harpoon:list():select(2)
		end)
		vim.keymap.set("n", "<leader>h3", function()
			harpoon:list():select(3)
		end)
		vim.keymap.set("n", "<leader>h4", function()
			harpoon:list():select(4)
		end)
		vim.keymap.set("n", "<leader>h5", function()
			harpoon:list():select(5)
		end)
		vim.keymap.set("n", "<leader>h6", function()
			harpoon:list():select(6)
		end)
		vim.keymap.set("n", "<leader>h7", function()
			harpoon:list():select(7)
		end)
		vim.keymap.set("n", "<leader>h8", function()
			harpoon:list():select(8)
		end)
		vim.keymap.set("n", "<leader>h9", function()
			harpoon:list():select(9)
		end)

		-- Open next harpoon buffer
		vim.keymap.set("n", "<C-S-P>", function()
			harpoon:list():prev()
		end)
		vim.keymap.set("n", "<C-S-N>", function()
			harpoon:list():next()
		end)
	end,
}
