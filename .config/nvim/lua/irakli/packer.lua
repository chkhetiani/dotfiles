vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
    use 'wbthomason/packer.nvim'
    use {
        'nvim-telescope/telescope.nvim', tag = '0.1.4',
        requires = { { 'nvim-lua/plenary.nvim' } }
    }
    use { 'nvim-telescope/telescope-ui-select.nvim' }

    -- themes
    use({
        'rose-pine/neovim',
        as = 'rose-pine',
        config = function()
            require('rose-pine').setup()
        end
        -- vim.cmd('colorscheme rose-pine')
    })
    use 'folke/tokyonight.nvim'
    use { 'catppuccin/nvim', as = 'catppuccin' }
    use {
        'projekt0n/github-nvim-theme', version = 'v0.0.7',
        config = function()
            require('github-theme').setup({
            })
            -- vim.cmd('colorscheme github_dark')
        end
    }
    -- end themes


    use('nvim-treesitter/nvim-treesitter', { run = ':TSUpdate' })
    use({
        "nvim-treesitter/nvim-treesitter-textobjects",
        after = "nvim-treesitter",
        requires = "nvim-treesitter/nvim-treesitter",
    })
    use { 'rush-rs/tree-sitter-asm' }
    use { 'nvim-treesitter/nvim-treesitter-context' }
    use 'mbbill/undotree'
    use 'tpope/vim-fugitive'
    use {
        'stevearc/oil.nvim',
        -- requires = { 'nvim-tree/nvim-web-devicons' },
        -- config = function() require('oil').setup() end
    }
    -- debugger
    use 'mfussenegger/nvim-dap'
    use { 'rcarriga/nvim-dap-ui', requires = { 'mfussenegger/nvim-dap' } }
    use 'mfussenegger/nvim-jdtls'
    use 'theHamsta/nvim-dap-virtual-text'
    use 'leoluz/nvim-dap-go'

    -- end debugger

    use 'ThePrimeagen/harpoon'
    use 'ThePrimeagen/git-worktree.nvim'
    use 'ThePrimeagen/vim-be-good'

    use {
        "ThePrimeagen/refactoring.nvim",
        requires = {
            { "nvim-lua/plenary.nvim" },
            { "nvim-treesitter/nvim-treesitter" }
        }
    }


    use {
        'nvim-lualine/lualine.nvim',
    }
    use { 'lewis6991/gitsigns.nvim' }

    use { 'numToStr/Comment.nvim' }

    use 'christoomey/vim-tmux-navigator'

    use { 'github/copilot.vim' }

    use {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v1.x',
        requires = {
            -- LSP Support
            { 'neovim/nvim-lspconfig' },             -- Required
            { 'williamboman/mason.nvim' },           -- Optional
            { 'williamboman/mason-lspconfig.nvim' }, -- Optional
            { 'folke/neodev.nvim' },


            -- Autocompletion
            { 'hrsh7th/nvim-cmp' },         -- Required
            { 'hrsh7th/cmp-nvim-lsp' },     -- Required
            { 'hrsh7th/cmp-buffer' },       -- Optional
            { 'hrsh7th/cmp-path' },         -- Optional
            { 'saadparwaiz1/cmp_luasnip' }, -- Optional
            { 'hrsh7th/cmp-nvim-lua' },     -- Optional

            -- Snippets
            { 'L3MON4D3/LuaSnip' },             -- Required
            { 'rafamadriz/friendly-snippets' }, -- Optional
        }
    }
end)
