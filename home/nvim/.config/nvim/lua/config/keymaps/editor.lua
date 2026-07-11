-- Editor keymaps: Cloak, JSX macros, JS/TS log macro, format

local esc = vim.api.nvim_replace_termcodes("<Esc>", true, true, true)

-- Cloak toggle
vim.keymap.set("n", "<leader>ct", ":CloakToggle<CR>", { desc = "Toggle cloak" })

-- Format file
vim.keymap.set("n", "<leader>cf", function()
	require("conform").format({ bufnr = 0 })
end, { desc = "Format file" })

-- JS/TS console.log macro
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("JsLogMacro", { clear = true }),
    pattern = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
    callback = function()
        vim.keymap.set("n", "<leader>cl", function()
            -- Get the word under the cursor
            local word = vim.fn.expand("<cword>")
            -- Get current cursor position to jump back (like your 'mz')
            local cursor = vim.api.nvim_win_get_cursor(0)
            -- Construct and insert the line
            local line = string.format("console.log('%s: ', %s);", word, word)
            vim.fn.append(vim.fn.line("."), line)
            -- Restore cursor (the `z)
            vim.api.nvim_win_set_cursor(0, cursor)
        end, { buffer = true, desc = "Insert console.log for word under cursor" })
    end,
})

-- JSX/TSX comment/uncomment macros
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("JsxMacro", { clear = true }),
	pattern = { "javascriptreact", "typescriptreact" },
	callback = function()
		local comment_macro = "0i{/*" .. esc .. "$a*/}" .. esc .. "j0w"
		vim.fn.setreg("c", comment_macro)
		vim.keymap.set("n", "<leader>cc", "@c", { buffer = true, desc = "Comment line (JSX/TSX)" })

		local uncomment_macro = "0wxxx$xxxj"
		vim.fn.setreg("u", uncomment_macro)
		vim.keymap.set("n", "<leader>cu", "@u", { buffer = true, desc = "Uncomment line (JSX/TSX)" })
	end,
})
