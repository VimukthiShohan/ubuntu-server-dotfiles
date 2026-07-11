-- LSP keymaps: buffer-local, registered on LspAttach

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("LspKeymaps", { clear = true }),
	callback = function(e)
		local opts = { buffer = e.buf }

		vim.keymap.set("n", "<leader>ld", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Go to definition" }))
		vim.keymap.set("n", "<leader>lr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "Find references" }))
		vim.keymap.set("n", "<leader>ln", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename" }))
		vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Code action" }))
		vim.keymap.set("n", "<leader>lw", vim.lsp.buf.workspace_symbol, vim.tbl_extend("force", opts, { desc = "Workspace symbol" }))
		vim.keymap.set("n", "<leader>lh", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover" }))
		vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help, vim.tbl_extend("force", opts, { desc = "Signature help" }))
	end,
})