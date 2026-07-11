return {
	"lewis6991/gitsigns.nvim",
	config = function()
		require("gitsigns").setup({
			on_attach = function(bufnr)
				local gs = require("gitsigns")

				local function map(mode, l, r, desc)
					vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
				end

				map("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
				map("n", "<leader>gS", gs.stage_buffer, "Stage buffer")
				map("n", "<leader>gu", gs.undo_stage_hunk, "Unstage hunk")
				map("n", "<leader>gU", gs.reset_buffer, "Reset buffer")
				map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
				map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
				map("n", "<leader>gb", function()
					gs.blame_line({ full = true })
				end, "Blame line")
				map("n", "<leader>gd", gs.diffthis, "Diff this")
				map("n", "<leader>gt", gs.toggle_current_line_blame, "Toggle blame")
			end,
		})
	end,
}