local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>S', builtin.find_files, {})
vim.keymap.set('n', '<leader>s', builtin.git_files, {})
vim.keymap.set('n', '<leader>r', function() 
	builtin.grep_string({ search = vim.fn.input("Grep > ") });
end)

vim.keymap.set('n', '<leader>td', builtin.diagnostics, {})
vim.keymap.set('n', '<leader>tr', builtin.lsp_references, {})
vim.keymap.set('n', '<leader>tb', builtin.builtin, {})
vim.keymap.set('n', '<leader>tj', builtin.git_branches, {})
vim.keymap.set('n', '<leader>tr', builtin.lsp_references, {})

require("telescope").setup {
  extensions = {
    ["ui-select"] = {
      require("telescope.themes").get_dropdown {
        -- even more opts
      }

      -- pseudo code / specification for writing custom displays, like the one
      -- for "codeactions"
      -- specific_opts = {
      --   [kind] = {
      --     make_indexed = function(items) -> indexed_items, width,
      --     make_displayer = function(widths) -> displayer
      --     make_display = function(displayer) -> function(e)
      --     make_ordinal = function(e) -> string
      --   },
      --   -- for example to disable the custom builtin "codeactions" display
      --      do the following
      --   codeactions = false,
      -- }
    }
  }
}
-- To get ui-select loaded and working with telescope, you need to call
-- load_extension, somewhere after setup function:
require("telescope").load_extension("ui-select")
