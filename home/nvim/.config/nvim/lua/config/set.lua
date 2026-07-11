vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50

pcall(function()
    vim.opt.winborder = "rounded"
end)

vim.opt.clipboard = "unnamedplus"

vim.g.lazyvim_prettier_needs_config = true

vim.opt.cursorline = true

vim.opt.foldcolumn = "0"
vim.opt.foldlevel = 99
vim.opt.foldenable = true
vim.opt.foldopen = ""
