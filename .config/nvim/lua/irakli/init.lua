require("irakli.set")
require("irakli.remap")
require("irakli.lazy")
require("irakli.open_stats")

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


vim.g.gui_font_default_size = 9
vim.g.gui_font_size = vim.g.gui_font_default_size
vim.g.gui_font_face = "SauceCodePro Nerd Font:h10"

RefreshGuiFont = function()
  vim.opt.guifont = string.format("%s:h%s",vim.g.gui_font_face, vim.g.gui_font_size)
end

ResizeGuiFont = function(delta)
  vim.g.gui_font_size = vim.g.gui_font_size + delta
  RefreshGuiFont()
end

ResetGuiFont = function ()
  vim.g.gui_font_size = vim.g.gui_font_default_size
  RefreshGuiFont()
end

ResetGuiFont()

local opts = { noremap = true, silent = true }

vim.keymap.set({'n', 'i'}, "<C-+>", function() ResizeGuiFont(1)  end, opts)
vim.keymap.set({'n', 'i'}, "<C-->", function() ResizeGuiFont(-1) end, opts)
vim.keymap.set({'n', 'i'}, "<C-BS>", function() ResetGuiFont() end, opts)
