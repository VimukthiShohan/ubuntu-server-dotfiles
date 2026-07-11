-- Markdown preview keymaps

vim.keymap.set("n", "<leader>mo", function()
	local filepath = vim.fn.expand("%:p")
	if filepath == "" then
		vim.notify("No file open", vim.log.levels.WARN)
		return
	end
	vim.system({ "open", "-a", "zen", filepath }, { detach = true })
end, { desc = "Open in Zen" })
