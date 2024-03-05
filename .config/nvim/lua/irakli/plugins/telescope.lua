return {
    "nvim-telescope/telescope.nvim",
    config = function()
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

        require("telescope").load_extension("ui-select")
    end,
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope-ui-select.nvim",
    },
}
