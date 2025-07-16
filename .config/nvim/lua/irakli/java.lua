local M = {};
function M.Init()
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
            local java_debug_path =
            '/home/irakli/.local/share/nvim/mason/share/java-debug-adapter/com.microsoft.java.debug.plugin.jar'

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
                    '/home/irakli/.local/share/nvim/mason/share/jdtls/plugins/org.eclipse.equinox.launcher_1.7.0.v20250331-1702.jar',
                    '-configuration', '/home/irakli/.local/share/nvim/mason/share/jdtls/config',
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
                -- Add DAP integration
                on_attach = function(client, bufnr)
                    require('jdtls').setup_dap({ hotcodereplace = 'auto' })
                    require('jdtls.dap').setup_dap_main_class_configs()
                end,
            }
            require("jdtls").start_or_attach(config)
        end,
    })

    return true
end

return M
