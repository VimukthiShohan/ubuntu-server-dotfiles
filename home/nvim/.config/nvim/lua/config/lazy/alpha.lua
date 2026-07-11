return {
	"goolord/alpha-nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		local alpha = require("alpha")
		local dashboard = require("alpha.themes.dashboard")

		dashboard.section.header.val = {
			"$$\\      $$\\                 $$\\      $$\\                                         $$\\                               ",
			"$$$\\    $$$ |                $$$\\    $$$ |                                        $$ |                              ",
			"$$$$\\  $$$$ | $$$$$$\\        $$$$\\  $$$$ | $$$$$$\\   $$$$$$\\ $$\\    $$\\  $$$$$$\\  $$ | $$$$$$\\  $$\\   $$\\  $$$$$$$\\ ",
			"$$\\$$\\$$ $$ |$$  __$$\\       $$\\$$\\$$ $$ | \\____$$\\ $$  __$$\\\\$$\\  $$  |$$  __$$\\ $$ |$$  __$$\\ $$ |  $$ |$$  _____|",
			"$$ \\$$$  $$ |$$ |  \\__|      $$ \\$$$  $$ | $$$$$$$ |$$ |  \\__|\\$$\\$$  / $$$$$$$$ |$$ |$$ /  $$ |$$ |  $$ |\\$$$$$$\\  ",
			"$$ |\\$  /$$ |$$ |            $$ |\\$  /$$ |$$  __$$ |$$ |       \\$$$  /  $$   ____|$$ |$$ |  $$ |$$ |  $$ | \\____$$\\ ",
			"$$ | \\_/ $$ |$$ |$$\\         $$ | \\_/ $$ |\\$$$$$$$ |$$ |        \\$  /   \\$$$$$$$\\ $$ |\\$$$$$$  |\\$$$$$$  |$$$$$$$  |",
			"\\__|     \\__|\\__|\\__|        \\__|     \\__| \\_______|\\__|         \\_/     \\_______|\\__| \\______/  \\______/ \\_______/ ",
		}
		dashboard.opts.layout[1].val = 8

		dashboard.section.buttons.val = {
			dashboard.button("v", "  Goto neovim config", ":cd ~/.config/nvim <CR>"),
			dashboard.button("c", "  Goto dotfiles", ":cd ~/.dotfiles <CR>"),
			dashboard.button("n", "  Open nix config", ":e ~/.dotfiles/nix/flake.nix <CR>"),
			dashboard.button("q", "󰅚  Quit", ":qa<CR>"),
		}

		alpha.setup(dashboard.config)
	end,
}
