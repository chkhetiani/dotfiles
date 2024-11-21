return {
    'neovim/nvim-lspconfig',
    dependencies = {
        'williamboman/mason.nvim',
        'williamboman/mason-lspconfig.nvim',
        'WhoIsSethDaniel/mason-tool-installer.nvim',
        'neovim/nvim-lspconfig',
        'mfussenegger/nvim-jdtls',
        -- { 'j-hui/fidget.nvim', opts = {} },
    },
    config = function()
        vim.lsp.set_log_level("debug")

        vim.api.nvim_create_autocmd('LspAttach', {
            group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
            callback = function(event)
                local map = function(keys, func, desc)
                    vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
                end

                local vmap = function(keys, func, desc)
                    vim.keymap.set('v', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
                end

                map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
                map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
                map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
                map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
                map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
                map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
                map('<leader>f', vim.lsp.buf.format, '[F]ormat')

                map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
                map('<leader>c', vim.lsp.buf.code_action, '[C]ode [A]ction')
                vmap('<leader>c', vim.lsp.buf.code_action, '[C]ode [A]ction')
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
            ts_ls = {
                init_options = {
                    preferences = {
                        importModuleSpecifierPreference = 'relative',
                        importModuleSpecifierEnding = 'minimal',
                    },
                }
            },
            omnisharp = {},
            jdtls = {
                cmd = { '/home/irakli/.local/share/nvim/mason/bin/jdtls' },
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
                jdtls = function()
                    vim.api.nvim_create_autocmd("FileType", {
                        pattern = "java",
                        callback = function(event)
                            local map = function(mode, keys, func, desc)
                                vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
                            end

                            map('n', '<leader>gi', require('jdtls').organize_imports, '[O]rganize [I]mports')
                            map('v', '<leader>de', '<Esc><Cmd>lua require("jdtls").extract_variable(true)<CR>',
                                'Extract Variable')
                            map('n', '<leader>de', require('jdtls').extract_variable, 'Extract Variable')
                            map('v', '<leader>dm', '<Esc><Cmd>lua require("jdtls").extract_method(true)<CR>',
                                'Extract Method')

                            local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
                            local workspace_dir = '/home/irakli/.local/share/java_workspaces/' .. project_name
                            local config = {
                                cmd = {
                                    'java',
                                    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
                                    '-Dosgi.bundles.defaultStartLevel=4',
                                    '-Declipse.product=org.eclipse.jdt.ls.core.product',
                                    '-Dlog.protocol=true',
                                    '-Dlog.level=ALL',
                                    '-Xmx1g',
                                    '--add-modules=ALL-SYSTEM',
                                    '--add-opens', 'java.base/java.util=ALL-UNNAMED',
                                    '--add-opens', 'java.base/java.lang=ALL-UNNAMED',

                                    '-jar',
                                    '/home/irakli/.local/share/nvim/mason/share/jdtls/plugins/org.eclipse.equinox.launcher_1.6.900.v20240613-2009.jar',
                                    '-configuration', '/home/irakli/.local/share/nvim/mason/share/jdtls/config',

                                    '-data', workspace_dir
                                },

                                root_dir = vim.fs.root(0, { ".git", "mvnw", "gradlew" }),

                                -- Here you can configure eclipse.jdt.ls specific settings
                                -- See https://github.com/eclipse/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
                                -- for a list of options
                                settings = {
                                    java = {
                                        -- This doesn't work but let's keep it.
                                        -- Might start working
                                        -- Never Know
                                        signatureHelp = { enabled = true },
                                        contentProvider = { preferred = 'fernflower' },
                                        completion = {
                                            favoriteStaticMembers = {
                                                "java.util.*"
                                            },
                                            filteredTypes = {
                                                "com.sun.*",
                                                -- "java.awt.*",
                                                -- "jdk.*", "sun.*",
                                            },
                                        },
                                    }
                                },

                                -- Language server `initializationOptions`
                                -- You need to extend the `bundles` with paths to jar files
                                -- if you want to use additional eclipse.jdt.ls plugins.
                                --
                                -- See https://github.com/mfussenegger/nvim-jdtls#java-debug-installation
                                --
                                init_options = {
                                    bundles = {
                                        vim.fn.glob(
                                            '/home/irakli/.local/share/nvim/mason/share/java-debug-adapter/com.microsoft.java.debug.plugin.jar',
                                            true)
                                    },
                                },
                                -- handlers = {
                                --     ["language/status"] = function(_, result)
                                --         -- print(result)
                                --     end,
                                --     ["$/progress"] = function(_, result, ctx)
                                --         -- disable progress updates.
                                --     end,
                                -- },
                            }
                            require("jdtls").start_or_attach(config)
                        end,
                    })
                    return true
                end,
                ts_ls = function()
                    vim.api.nvim_create_autocmd("FileType", {
                        pattern = "ts",
                        callback = function(event)
                            vim.keymap.set('n', '<leader>gi', "<Cmd>TSToolsOrganizeImports<CR>",
                                { buffer = event.buf, desc = 'LSP: ' .. 'Or[g]anize [I]mports' })
                        end,
                    })
                    return true
                end
            },
        }
    end,
}
