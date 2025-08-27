return {
    'mfussenegger/nvim-dap',
    dependencies = {
        'rcarriga/nvim-dap-ui',
        'mfussenegger/nvim-jdtls',
        'theHamsta/nvim-dap-virtual-text',
        'nvim-neotest/nvim-nio'
        -- 'leoluz/nvim-dap-go',
    },
    config = function()
        vim.keymap.set("n", "<F1>", ":lua require'dap'.step_into()<CR>");
        vim.keymap.set("n", "<F2>", ":lua require'dap'.step_over()<CR>");
        vim.keymap.set("n", "<F3>", ":lua require'dap'.step_out()<CR>");
        vim.keymap.set("n", "<F5>", ":lua require'dap'.continue()<CR>");
        vim.keymap.set("n", "<leader>b", ":lua require'dap'.toggle_breakpoint()<CR>");
        vim.keymap.set("n", "<leader>B", ":lua require'dap'.set_breakpoint(vim.fn.input('Condition: '))<CR>");

        local dap = require('dap')
        dap.set_log_level('DEBUG')

        vim.keymap.set("n", "<space>gb", dap.run_to_cursor)

        -- Eval var under cursor
        vim.keymap.set("n", "<space>?", function()
            require("dapui").eval(nil, { enter = true })
        end)


        -- require('dap-go').setup()

        dap.adapters.coreclr = {
            type = 'executable',
            command = "/home/irakli/.local/share/nvim/mason/bin/netcoredbg",
            args = { '--interpreter=vscode' }
        }

        dap.configurations.cs = {
            {
                type = "coreclr",
                name = "launch - netcoredbg",
                request = "launch",
                program = function()
                    return vim.fn.input('Path to dll', vim.fn.getcwd() .. '/bin/Debug/', 'file')
                end,
            }
        }

        dap.adapters.java = {
            type = 'executable',
            command = 'java',
            args = {
                '-jar',
                '/home/irakli/.local/share/nvim/mason/share/java-debug-adapter/com.microsoft.java.debug.plugin.jar'
            },
        }

        dap.configurations.java = {
            {
                type = 'java',
                request = 'attach',
                name = 'Attach to Jetty',
                hostName = '127.0.0.1',
                port = 5005,
            },
        }

        -- dap.adapters.java = {
        --     type = 'executable',
        --     command = 'java',
        --     args = { '-jar', '/home/irakli/.local/share/nvim/mason/share/java-debug-adapter/com.microsoft.java.debug.plugin.jar' },
        -- }

        -- dap.adapters.java = {
        --     type = 'server',
        --     host = '127.0.0.1',
        --     port = 5005,
        --     initialize = function()
        --         print("Connecting to 127.0.0.1:5005")
        --     end,
        -- }
        --
        -- dap.configurations.java = {
        --     {
        --         type = 'java',
        --         request = 'attach',
        --         name = 'Debug (Attach) - Remote Jetty',
        --         hostName = '127.0.0.1',
        --         port = 5005,
        --     },
        -- }

        dap.adapters.delve = {
            type = 'server',
            port = '${port}',
            executable = {
                command = 'dlv',
                args = { 'dap', '-l', '127.0.0.1:${port}' },
            }
        }

        -- https://github.com/go-delve/delve/blob/master/Documentation/usage/dlv_dap.md
        dap.configurations.go = {
            {
                type = "delve",
                name = "Debug .",
                request = "launch",
                program = "."
            },
            {
                type = "delve",
                name = "Debug",
                request = "launch",
                program = "${file}"
            },
            {
                type = "delve",
                name = "Debug test", -- configuration for debugging test files
                request = "launch",
                mode = "test",
                program = "${file}"
            },
            -- works with go.mod packages and sub packages
            {
                type = "delve",
                name = "Debug test (go.mod)",
                request = "launch",
                mode = "test",
                program = "./${relativeFileDirname}"
            }
        }

        require("nvim-dap-virtual-text").setup {
            -- This just tries to mitigate the chance that I leak tokens here. Probably won't stop it from happening...
            display_callback = function(variable)
                local name = string.lower(variable.name)
                local value = string.lower(variable.value)
                if name:match "secret" or name:match "api" or value:match "secret" or value:match "api" then
                    return "*****"
                end

                if #variable.value > 15 then
                    return " " .. string.sub(variable.value, 1, 15) .. "... "
                end

                return " " .. variable.value
            end,
        }


        require('dapui').setup()


        local dap, dapui = require("dap"), require("dapui")
        dap.listeners.after.event_initialized["dapui_config"] = function()
            dapui.open()
        end
        dap.listeners.after.event_terminated["dapui_config"] = function()
            dapui.close()
        end
        dap.listeners.after.event_exited["dapui_config"] = function()
            dapui.close()
        end
    end,
}
