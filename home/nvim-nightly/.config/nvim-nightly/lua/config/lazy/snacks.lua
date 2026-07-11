return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		picker = {
			enabled = true,
			exclude = {
				".git",
				"node_modules",
				".venv",
				"venv",
				"__pycache__",
			},
			hidden = true,
			ignored = true,
			sources = {
				files = {
					hidden = true,
					ignored = true,
				},
			},
		},
		explorer = {
			enabled = true,
			git = {
				enabled = true,
				untracked = true,
			},
			exclude = {
				".git",
				"node_modules",
				".venv",
				"venv",
				"__pycache__",
			},
			files = {
				hidden = true,
				ignored = true,
				ignore_patterns = {
					".git",
					"node_modules",
					".venv",
					"venv",
					"__pycache__",
				},
			},
		},
		dashboard = {
			enabled = true,
			preset = {
				-- Alpha header -> Snacks header
				header = table.concat({
					"$$\\      $$\\                 $$\\      $$\\                                         $$\\                               ",
					"$$$\\    $$$ |                $$$\\    $$$ |                                        $$ |                              ",
					"$$$$\\  $$$$ | $$$$$$\\        $$$$\\  $$$$ | $$$$$$\\   $$$$$$\\ $$\\    $$\\  $$$$$$\\  $$ | $$$$$$\\  $$\\   $$\\  $$$$$$$\\ ",
					"$$\\$$\\$$ $$ |$$  __$$\\       $$\\$$\\$$ $$ | \\____$$\\ $$  __$$\\\\$$\\  $$  |$$  __$$\\ $$ |$$  __$$\\ $$ |  $$ |$$  _____|",
					"$$ \\$$$  $$ |$$ |  \\__|      $$ \\$$$  $$ | $$$$$$$ |$$ |  \\__|\\$$\\$$  / $$$$$$$$ |$$ |$$ /  $$ |$$ |  $$ |\\$$$$$$\\  ",
					"$$ |\\$  /$$ |$$ |            $$ |\\$  /$$ |$$  __$$ |$$ |       \\$$$  /  $$   ____|$$ |$$ |  $$ |$$ |  $$ | \\____$$\\ ",
					"$$ | \\_/ $$ |$$ |$$\\         $$ | \\_/ $$ |\\$$$$$$$ |$$ |        \\$  /   \\$$$$$$$\\ $$ |\\$$$$$$  |\\$$$$$$  |$$$$$$$  |",
					"\\__|     \\__|\\__|\\__|        \\__|     \\__| \\_______|\\__|         \\_/     \\_______|\\__| \\______/  \\______/ \\_______/ ",
				}, "\n"),

				-- Alpha buttons -> Snacks keys
				-- (Snacks uses "keys" items with: key, desc, action, icon)
				keys = {
					{
						icon = " ",
						key = "v",
						desc = "Goto neovim config",
						action = ":cd ~/.config/nvim",
					},
					{
						icon = " ",
						key = "c",
						desc = "Goto dotfiles",
						action = ":cd ~/.dotfiles",
					},
					{
						icon = " ",
						key = "n",
						desc = "Open nix config",
						action = ":e ~/.dotfiles/nix/flake.nix",
					},
					{
						icon = "󰅚 ",
						key = "q",
						desc = "Quit",
						action = ":qa",
					},
				},
			},
		},
		bigfile = { enabled = true },
		explorer = { enabled = true },
		indent = { enabled = true },
		input = { enabled = true },
		picker = { enabled = true },
		notifier = { enabled = true },
		quickfile = { enabled = true },
		scope = { enabled = true },
		scroll = { enabled = true },
		statuscolumn = { enabled = true },
		words = { enabled = true },
		terminal = {
			win = {
				style = "float",
			},
		},
		surround = {
			enabled = true,
		},
	},
	keys = {
		{
			"<leader><space>",
			function()
				Snacks.picker.files()
			end,
			desc = "Find Files",
		},
		{
			"<leader>s<space>",
			function()
				Snacks.picker.files()
			end,
			desc = "Find Files",
		},
		{
			"<leader>,",
			function()
				Snacks.picker.buffers()
			end,
			desc = "Buffers",
		},
		{
			"<leader>/",
			function()
				Snacks.picker.grep()
			end,
			desc = "Grep",
		},
		{
			"<leader>n",
			function()
				Snacks.picker.notifications()
			end,
			desc = "Notification History",
		},
		{
			"<leader>e",
			function()
				Snacks.explorer()
			end,
			desc = "File Explorer",
		},
		{
			"<C-`>",
			function()
				Snacks.terminal.toggle()
			end,
			desc = "Toggle terminal on or off",
		},
	},
}
