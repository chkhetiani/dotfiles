return {
    'neovim/nvim-lspconfig',
    dependencies = {
        'williamboman/mason.nvim',
        'williamboman/mason-lspconfig.nvim',
        'WhoIsSethDaniel/mason-tool-installer.nvim',
        'neovim/nvim-lspconfig',
        -- 'nvim-java/nvim-java',
        { 'j-hui/fidget.nvim', opts = {} },
    },
    config = function()
        vim.api.nvim_create_autocmd('LspAttach', {
            group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
            callback = function(event)
                local map = function(keys, func, desc)
                    vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
                end

                map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
                map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
                map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
                map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
                map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
                map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
                map('<leader>f', vim.lsp.buf.format, '[F]ormat')

                map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
                map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')
                map('K', vim.lsp.buf.hover, 'Hover Do[k]umentation')
                map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

                -- The following two autocommands are used to highlight references of the
                -- word under your cursor when your cursor rests there for a little while.
                --    See `:help CursorHold` for information about when this is executed
                --
                -- When you move your cursor, the highlights will be cleared (the second autocommand).
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

        local capabilities = vim.lsp.protocol.make_client_capabilities()
        capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

        local servers = {
            gopls = {},
            tsserver = {},
            omnisharp = {},
            jdtls = {
                cmd = { 'jdtls' },
                root_dir = require('lspconfig').util.root_pattern({ 'gradlew', 'mvnw', '.git' }),
            },
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
        }

        require('mason').setup()

        local ensure_installed = vim.tbl_keys(servers or {})
        vim.list_extend(ensure_installed, {
            -- 'stylua',
        })
        require('mason-tool-installer').setup { ensure_installed = ensure_installed }

        require('mason-lspconfig').setup {
            handlers = {
                function(server_name)
                    local server = servers[server_name] or {}
                    server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
                    require('lspconfig')[server_name].setup(server)
                end,
                -- jdtls = function()
                --     require('java').setup {}
                --     require('lspconfig').jdtls.setup {
                --         {
                --             root_markers = {
                --                 'mvnw',
                --                 '.git',
                --             },
                --
                --             java_test = {
                --                 enable = false,
                --             },
                --
                --             -- load java debugger plugins
                --             java_debug_adapter = {
                --                 enable = false,
                --             },
                --
                --             spring_boot_tools = {
                --                 enable = false,
                --             },
                --
                --             jdk = {
                --                 auto_install = true,
                --             },
                --
                --             notifications = {
                --                 -- enable 'Configuring DAP' & 'DAP configured' messages on start up
                --                 dap = false,
                --             },
                --
                --             verification = {
                --                 -- nvim-java checks for the order of execution of following
                --                 -- * require('java').setup()
                --                 -- * require('lspconfig').jdtls.setup()
                --                 -- IF they are not executed in the correct order, you will see a error
                --                 -- notification.
                --                 -- Set following to false to disable the notification if you know what you
                --                 -- are doing
                --                 invalid_order = true,
                --
                --                 -- nvim-java checks if the require('java').setup() is called multiple
                --                 -- times.
                --                 -- IF there are multiple setup calls are executed, an error will be shown
                --                 -- Set following property value to false to disable the notification if
                --                 -- you know what you are doing
                --                 duplicate_setup_calls = true,
                --
                --                 -- nvim-java checks if nvim-java/mason-registry is added correctly to
                --                 -- mason.nvim plugin.
                --                 -- IF it's not registered correctly, an error will be thrown and nvim-java
                --                 -- will stop setup
                --                 invalid_mason_registry = true,
                --             },
                --         }
                --     }
                -- end
            },
        }
    end,
}
