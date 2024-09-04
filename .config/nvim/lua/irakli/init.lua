require("irakli.set")
require("irakli.remap")
require("irakli.lazy")

local worktree = require("irakli.worktree")

worktree.setup()

vim.keymap.set("n", "<leader>wt", function() worktree.show_worktree({}) end, { desc = "show [W]ork[t]rees" })
