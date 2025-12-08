return {
    'neovim/nvim-lspconfig',
    dependencies = {
        'williamboman/mason.nvim',
        'williamboman/mason-lspconfig.nvim',
        'WhoIsSethDaniel/mason-tool-installer.nvim',
        'neovim/nvim-lspconfig',
        'mfussenegger/nvim-jdtls',
    },
    config = function()
        -- vim.lsp.set_log_level("off")
        vim.lsp.set_log_level("debug")

        vim.diagnostic.config({ virtual_text = true })

        -- LSP Attach Keymaps (unchanged)
        vim.api.nvim_create_autocmd('LspAttach', {
            group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
            callback = function(event)
                local map = function(keys, func, desc)
                    vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
                end
                local vmap = function(keys, func, desc)
                    vim.keymap.set('v', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
                end
                local imap = function(keys, func, desc)
                    vim.keymap.set('i', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
                end
                map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
                map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
                map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
                map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
                map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
                map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
                map('<leader>f', vim.lsp.buf.format, '[F]ormat')
                map('<C-s>', vim.lsp.buf.signature_help, '[S]ignature help')
                imap('<C-s>', vim.lsp.buf.hover, '[S]ignature help')
                map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
                map('<leader>c', vim.lsp.buf.code_action, '[C]ode [A]ction')
                vmap('<leader>c', vim.lsp.buf.code_action, '[C]ode [A]ction')
                map('K', vim.lsp.buf.hover, 'Hover Do[k]umentation')
                map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
                local client = vim.lsp.get_client_by_id(event.data.client_id)
                if client and client.server_capabilities.documentHighlightProvider then
                    vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
                        buffer = event.buf,
                        callback = vim.lsp.buf.document_highlight,
                    })
                    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
                        buffer = event.buf,
                        callback = vim.lsp.buf.clear_references,
                    })
                end
            end,
        })

        local capabilities = vim.tbl_deep_extend('force', vim.lsp.protocol.make_client_capabilities(),
            require('cmp_nvim_lsp').default_capabilities())

        local servers = {
            gopls = {},
            -- ts_ls = {
            --     init_options = {
            --         preferences = {
            --             importModuleSpecifierPreference = 'relative',
            --             importModuleSpecifierEnding = 'minimal',
            --         },
            --     }
            -- },
            -- omnisharp = {},
            -- jdtls = {
            --     root_dir = vim.fs.root(0, { ".git", "mvnw", "gradlew" }),
            -- },
            lua_ls = {
                settings = {
                    Lua = {
                        runtime = { version = 'LuaJIT' },
                        workspace = {
                            checkThirdParty = false,
                            library = {
                                '${3rd}/luv/library',
                                unpack(vim.api.nvim_get_runtime_file('', true)),
                            },
                        },
                        completion = {
                            callSnippet = 'Replace',
                        },
                    },
                },
            },
            clangd = {
                cmd = {
                    'clangd',
                    '--offset-encoding=utf-16',
                    '--clang-tidy',
                    '--cross-file-rename',
                    '--fallback-style=Chromium',
                },
                root_dir = require('lspconfig.util').root_pattern('compile_commands.json', '.git'),
                single_file_support = false,
                on_attach = function(client, bufnr)
                    client.server_capabilities.semanticTokensProvider = nil
                    require('lspconfig').clangd.default_on_attach(client, bufnr)
                end,
                settings = {
                    clangd = {
                        fallbackFlags = {
                            '-std=c++20',
                            '-Wall',
                            '-Wextra',
                            '-pedantic',
                        },
                        checkUpdates = true,
                        semanticHighlighting = true,
                        ['use.clang-format'] = true,
                        ['clangd.format.style'] = 'file',
                    },
                    ['clang-format'] = {
                        style = 'file',
                    },
                },
            },
            ['clang-format'] = {
                style = 'file',
                config = {
                    BasedOnStyle = 'Google',
                    IndentWidth = 4,
                    UseTab = 'Never',
                    BreakBeforeBraces = 'Allman',
                },
            },
        };

        vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
            pattern = "*.cl",
            callback = function()
                vim.bo.filetype = "c"
            end,
        })

        require('mason').setup({
            registries = {
                "github:mason-org/mason-registry",
                "github:Crashdummyy/mason-registry",
            }
        });
        local ensure_installed = vim.tbl_keys(servers or {})
        require('mason-tool-installer').setup { ensure_installed = ensure_installed }

        vim.api.nvim_create_autocmd("FileType", {
            pattern = "typescript",
            callback = function(event)
                vim.keymap.set('n', '<leader>gi', "<Cmd>TSToolsOrganizeImports<CR>",
                    { buffer = event.buf, desc = 'LSP: Or[g]anize [I]mports' })
                vim.keymap.set('n', '<leader>gm', "<Cmd>TSToolsAddMissingImports<CR>",
                    { buffer = event.buf, desc = 'LSP: Add missin[g] i[m]ports' })
            end,
        })

        vim.api.nvim_create_autocmd("FileType", {
            pattern = "go",
            callback = function(event)
                local bufopts = { noremap = true, silent = true }
                vim.keymap.set('n', '<leader>gi', function()
                    vim.lsp.buf.code_action({
                        context = { diagnostics = {}, only = { 'source.organizeImports' }, },
                        apply = true
                    })
                end, vim.tbl_extend('force', bufopts, { desc = 'Organize Imports' }))
            end,
        })

        require('mason-lspconfig').setup {
            ensure_installed = {},
            automatic_enable = {
                exclude = { 'jdtls' },  -- Exclude jdtls from automatic setup
            },
            handlers = {
                function(server_name)
                    local server = servers[server_name] or {}
                    server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
                    require('lspconfig')[server_name].setup(server)
                end,
                jdtls = function()
                    -- Skip mason-lspconfig setup, we handle it ourselves
                    return true
                end,
                ts_ls = function()
                    return true
                end
            },
        }

        local java = require('irakli.java')
        java.Init();
    end,
}
