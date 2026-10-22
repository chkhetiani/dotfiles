return {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    opts = {
        -- One LSP client / tsserver for the whole monorepo instead of one per
        -- workspace tsconfig. tsserver still resolves each tsconfig as its own
        -- project (the plugin already passes --useInferredProjectPerProjectRoot).
        root_dir = function(bufnr, on_dir)
            on_dir(vim.fs.root(bufnr, '.git') or vim.fn.getcwd())
        end,
        settings = {
            tsserver_file_preferences = {
                importModuleSpecifierPreference = 'relative',
                importModuleSpecifierEnding = 'minimal',
            }
        }
    },
}
