require("irakli.set")
require("irakli.remap")
require("irakli.lazy")
require("irakli.open_stats")
require("irakli.jdb")

local worktree = require("irakli.worktree")
local stats = require("irakli.open_stats")

worktree.setup()

vim.keymap.set("n", "<leader>wt", function() worktree.show_worktree({}) end, { desc = "show [W]ork[t]rees" })
vim.keymap.set("n", "<leader>wc", ":WorkTreeCreate x<CR>", { desc = "[C]reate [W]orktree" })
vim.keymap.set("n", "<leader>wr", ":WorkTreeRemove x<CR>", { desc = "[R]remove [W]orktree" })
vim.keymap.set("n", "<leader>os", function() stats.open(); end, { desc = "Open Stats" })

vim.api.nvim_create_autocmd("DirChanged", {
    pattern = "*",
    callback = function()
        local lazy = require("lazy")
        local plugin_name = "harpoon"
        lazy.reload({ plugins = { plugin_name } })
        local harpoon = require("harpoon")
        harpoon:setup()
    end
})
