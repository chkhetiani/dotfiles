local M = {};
function M.Init()

    vim.api.nvim_create_autocmd("FileType", {
        pattern = "java",
        callback = function(event)

            -- Stop any existing jdtls instances
            local existing_clients = vim.lsp.get_clients({ name = 'jdtls' })
            for _, client in ipairs(existing_clients) do
                vim.lsp.stop_client(client.id, true)
            end

            -- Wait for clients to stop before starting new one
            vim.defer_fn(function()

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
                local java_debug_path = vim.fn.stdpath('data') ..
                    '/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-0.53.2.jar'

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
                        vim.fn.glob(vim.fn.stdpath('data') ..
                            '/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar'),
                        '-configuration', vim.fn.stdpath('data') .. '/mason/packages/jdtls/config_linux',
                        '-data', workspace_dir
                    },
                    root_dir = vim.fs.root(0, { ".git", "mvnw", "gradlew" }),
                    settings = {
                        java = {
                            signatureHelp = { enabled = true },
                            contentProvider = { preferred = 'fernflower' },
                            completion = {
                                favoriteStaticMembers = { "java.util.*" },
                                filteredTypes = { "com.sun.*" },
                            },
                        }
                    },
                    init_options = {
                        bundles = { java_debug_path },
                    },
                    on_attach = function(client, bufnr)

                        vim.defer_fn(function()
                            local ok, jdtls = pcall(require, 'jdtls')
                            if ok then
                                local success, err = pcall(jdtls.setup_dap, {
                                    hotcodereplace = 'auto',
                                    config_overrides = {},
                                })
                                if success then
                                    print("=== DAP setup successful ===")
                                else
                                    print("=== DAP setup failed:", err, "===")
                                end
                            end
                        end, 5000)
                    end,
                }
                require("jdtls").start_or_attach(config)
            end, 1000) -- Wait 1 second for clients to stop
        end,
    })
    return true
end

return M
