local M = {}
local jdtls_setup = {}

local function setup_keymaps(bufnr)
    local map = function(mode, keys, func, desc)
        vim.keymap.set(mode, keys, func, { buffer = bufnr, desc = 'LSP: ' .. desc })
    end
    map('n', '<leader>gi', require('jdtls').organize_imports, '[O]rganize [I]mports')
    map('v', '<leader>de', '<Esc><Cmd>lua require("jdtls").extract_variable(true)<CR>', 'Extract Variable')
    map('n', '<leader>de', require('jdtls').extract_variable, 'Extract Variable')
    map('v', '<leader>dm', '<Esc><Cmd>lua require("jdtls").extract_method(true)<CR>', 'Extract Method')

    map('n', '<leader>gj', function()
        vim.opt_local.makeprg = './mvnw -q -B compile'
        vim.opt_local.errorformat = '[ERROR] %f:[%l\\,%c] %m,%-G%.%#'
        vim.cmd('silent make!')

        -- Maven repeats every error in its final summary, so drop the duplicates
        local seen, unique = {}, {}
        for _, item in ipairs(vim.fn.getqflist()) do
            local key = item.bufnr .. ':' .. item.lnum .. ':' .. item.col .. ':' .. item.text
            if not seen[key] then
                seen[key] = true
                table.insert(unique, item)
            end
        end
        vim.fn.setqflist(unique, 'r')

        vim.cmd('copen')
    end, '[M]aven compile')

end

local function setup_dap()
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
end

function M.Init()
    vim.api.nvim_create_autocmd("FileType", {
        pattern = "java",
        callback = function(event)
            local jdtls_config = vim.lsp.config.jdtls
            if not jdtls_config then
                vim.notify("jdtls config not found in vim.lsp.config", vim.log.levels.ERROR)
                return
            end

            -- Get root_dir using the config's root_dir function or root_markers
            local root_dir
            if type(jdtls_config.root_dir) == 'function' then
                jdtls_config.root_dir(event.buf, function(dir)
                    root_dir = dir
                end)
            elseif jdtls_config.root_markers then
                root_dir = vim.fs.root(event.buf, jdtls_config.root_markers)
            else
                root_dir = vim.fs.root(event.buf, { '.git', 'mvnw', 'gradlew' })
            end

            if not root_dir then
                return
            end

            -- Check if jdtls is already running for this root
            local existing_clients = vim.lsp.get_clients({ name = 'jdtls', bufnr = event.buf })
            if #existing_clients > 0 then
                -- Client already attached, just setup keymaps
                setup_keymaps(event.buf)
                return
            end

            -- Check if client exists for this root but not attached to this buffer
            local all_clients = vim.lsp.get_clients({ name = 'jdtls' })
            for _, client in ipairs(all_clients) do
                if client.config.root_dir == root_dir then
                    -- Attach existing client to this buffer
                    vim.lsp.buf_attach_client(event.buf, client.id)
                    setup_keymaps(event.buf)
                    return
                end
            end

            -- Only setup once per project
            if jdtls_setup[root_dir] then
                return
            end
            jdtls_setup[root_dir] = true

            local java_debug_path = vim.fn.stdpath('data') ..
                '/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-0.53.2.jar'

            -- Copy config but exclude 'cmd' since it's a function
            local base_config = {}
            for k, v in pairs(jdtls_config) do
                if k ~= 'cmd' then
                    base_config[k] = v
                end
            end

            -- Build cmd manually (lspconfig's cmd is a function). It MUST carry a
            -- per-root -data dir: without one, mason's jdtls wrapper derives the
            -- workspace from basename(cwd), so every project/worktree opened from
            -- the same cwd shares one Eclipse workspace (lock fights, re-indexing,
            -- memory blowup). Also cap the heap: wrapper sets -Xms1G and no -Xmx,
            -- so the JVM may grow to 1/4 of RAM (~8GB here).
            local data_dir = vim.fn.stdpath('cache') .. '/jdtls/workspace/' ..
                root_dir:gsub('^/', ''):gsub('/', '%%')
            local cmd = {
                'jdtls',
                '-data', data_dir,
                -- overrides the wrapper's hardcoded -Xms1G (last -Xms wins)
                '--jvm-arg=-Xms256m',
                '--jvm-arg=-Xmx2G',
                '--jvm-arg=-XX:+UseStringDeduplication',
            }

            local dap_setup_done = false
            local config = vim.tbl_deep_extend('force', base_config, {
                cmd = cmd,
                root_dir = root_dir,
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
                on_exit = function()
                    -- allow a restart for this root if the server stops/crashes
                    jdtls_setup[root_dir] = nil
                end,
                on_attach = function(_, bufnr)
                    setup_keymaps(bufnr)

                    -- Setup DAP only once per client
                    if not dap_setup_done then
                        dap_setup_done = true
                        -- Use LspAttach event to ensure server is fully initialized
                        vim.api.nvim_create_autocmd("LspAttach", {
                            once = true,
                            buffer = bufnr,
                            callback = function()
                                -- Small delay to ensure jdtls is fully ready
                                vim.defer_fn(setup_dap, 500)
                            end,
                        })
                    end
                end,
            })

            require("jdtls").start_or_attach(config)
        end,
    })

    -- When switching worktrees (cwd moves to a different checkout), stop jdtls
    -- servers whose project is unrelated to the new cwd instead of leaving a
    -- multi-GB JVM behind for every worktree visited.
    vim.api.nvim_create_autocmd("DirChanged", {
        callback = function()
            local cwd = vim.fn.getcwd()
            local function within(child, parent)
                return child == parent or vim.startswith(child, parent .. '/')
            end
            for _, client in ipairs(vim.lsp.get_clients({ name = 'jdtls' })) do
                local root = client.config.root_dir
                if root and not within(root, cwd) and not within(cwd, root) then
                    client:stop()
                end
            end
        end,
    })
    return true
end

return M
