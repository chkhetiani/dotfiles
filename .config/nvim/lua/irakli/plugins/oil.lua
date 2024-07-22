return {
    'stevearc/oil.nvim',
    opts = {
        keymaps = {
            ["g?"] = "actions.show_help",
            ["<CR>"] = "actions.select",
            ["<C-p>"] = "actions.preview",
            ["<C-c>"] = "actions.close",
            ["<C-l>"] = "actions.refresh",
            ["-"] = "actions.parent",
            ["_"] = "actions.open_cwd",
            ["`"] = "actions.cd",
            ["~"] = "actions.tcd",
            ["gs"] = "actions.change_sort",
            ["gx"] = "actions.open_external",
            ["g."] = "actions.toggle_hidden",
            ["g\\"] = "actions.toggle_trash",
        },
        use_default_keymaps = false,
        columns = {}
    },
    config = function()
        require("oil").setup({
            keymaps = {
                ["oo"] = {
                    desc = "Recursively Open directores",
                    callback = function()

                        local oil = require("oil")
                        local dir = oil.get_current_dir()
                        local cursor = oil.get_cursor_entry()

                        local function o()
                            oil.open(dir .. cursor.name)
                            vim.wait(50)

                            dir = oil.get_current_dir()
                            cursor = oil.get_cursor_entry()

                            local bn = vim.fn.bufnr()
                            local lines = vim.api.nvim_buf_line_count(bn)

                            if lines == 1 and cursor ~= nil and cursor.type == "directory" then
                                o()
                            end
                        end

                        o()
                    end,
                },
            },
        })

        vim.keymap.set("n", "<leader>e", require('oil').open, { desc = "Open parent directory" })
    end
}
