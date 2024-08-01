return {
    "nvim-telescope/telescope.nvim",
    config = function()
        local telescope = require("telescope");
        local builtin = require('telescope.builtin')

        local function is_git_repo()
            local handle = io.popen('git rev-parse --is-inside-work-tree 2>/dev/null')
            if handle == nil then
                return false
            end
            local result = handle:read('*a')
            handle:close()
            return result:match('true') ~= nil
        end

        local function find_files_or_git_files()
            if is_git_repo() then
                builtin.git_files()
            else
                builtin.find_files()
            end
        end

        vim.keymap.set('n', '<leader>S', builtin.find_files, {})
        vim.keymap.set('n', '<leader>s', find_files_or_git_files, {})
        vim.keymap.set('n', '<leader>r', function()
            builtin.grep_string({ search = vim.fn.input("Grep > ") });
        end)

        vim.keymap.set('n', '<leader>td', builtin.diagnostics, {})
        vim.keymap.set('n', '<leader>tr', builtin.lsp_references, {})
        vim.keymap.set('n', '<leader>tb', builtin.builtin, {})
        vim.keymap.set('n', '<leader>tj', builtin.git_branches, {})
        vim.keymap.set('n', '<leader>tr', builtin.lsp_references, {})

        require("telescope").load_extension("ui-select")

        telescope.setup({
            pickers = {
                git_branches = {
                    mappings = {
                        i = { ["<cr>"] = require("telescope.actions").git_switch_branch },
                    },
                },
            },
        })
    end,
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope-ui-select.nvim",
    },
}
