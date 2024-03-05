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
        require('oil').setup()
        vim.keymap.set("n", "<leader>e", require('oil').open, { desc = "Open parent directory" })
    end
}
