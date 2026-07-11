return {
  "akinsho/toggleterm.nvim",
  version = "*",
  config = function()
    require("toggleterm").setup({
      size = 15,
      -- This defines the toggle key
      open_mapping = [[<C-`>]],
      direction = "horizontal",
      -- Keeps the terminal distinct from code buffers
      shade_terminals = true,
      -- This ensures that when you open it, it's ready to type
      start_in_insert = true,
      persist_size = true,
    })
  end,
}
