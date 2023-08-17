return {
  setup = function()
    local builtin = require('telescope.builtin')
    vim.keymap.set('n', '<leader>f', builtin.find_files)
    vim.keymap.set('n', '<C-f>', builtin.live_grep)

    require('telescope').setup{
      defaults = {
        mappings = {
          i = {
            ["<C-h>"] = "which_key"
          },
        },
      },
    }
  end,
}
