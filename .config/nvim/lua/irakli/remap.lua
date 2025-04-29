vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.keymap.set("n", "J", "mzJ`z")
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")
vim.keymap.set("n", "gp", "`[v`]")
vim.keymap.set("n", "<leader><leader>", "<C-^>");


vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])

vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]])

vim.keymap.set("n", "<leader>;", "mzA;<Esc>`z")

vim.keymap.set("n", "<leader>q", "<cmd>nohlsearch<CR>")

vim.keymap.set("n", "Q", "<nop>")

vim.keymap.set("n", "<leader>k", "<cmd>cprev<CR>zz")
vim.keymap.set("n", "<leader>j", "<cmd>cnext<CR>zz")

vim.keymap.set("n", "<leader>re", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

vim.keymap.set("n", "<leader>vpp", "<cmd>e ~/.config/nvim/lua/irakli/init.lua<CR>");

vim.keymap.set("n", "<leader>lsp", "<cmd>LspRestart<CR>")
vim.keymap.set("n", "<leader>ww", ":wa<CR>")
vim.keymap.set("n", "<leader>oo", ":lua vim.ui.open(vim.loop.cwd())<CR>")
vim.keymap.set("n", "<leader>mi", ":!mvn install -f pom.xml<CR>")
