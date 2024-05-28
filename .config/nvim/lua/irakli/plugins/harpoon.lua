return {
    'ThePrimeagen/harpoon',
    branch = 'harpoon2',
    config = function()
        local harpoon = require("harpoon")

        harpoon:setup()

        vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end, { desc = "add new file to harpoon list" })
        vim.keymap.set('n', "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, {
            desc = "toggle harpoon files list" })

        vim.keymap.set("n", "<C-j>", function() harpoon:list():select(1) end, { desc = "harpoon - go to file #1" })
        vim.keymap.set("n", "<C-k>", function() harpoon:list():select(2) end, { desc = "harpoon - go to file #2" })
        vim.keymap.set("n", "<C-l>", function() harpoon:list():select(3) end, { desc = "harpoon - go to file #3" })
    end
}
