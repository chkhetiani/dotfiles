return {
    'mfussenegger/nvim-dap',
    dependencies = {
        'rcarriga/nvim-dap-ui',
        'mfussenegger/nvim-jdtls',
        'theHamsta/nvim-dap-virtual-text',
        'leoluz/nvim-dap-go',
    },
    config = function()
        vim.keymap.set("n", "<F1>", ":lua require'dap'.step_into()<CR>");
        vim.keymap.set("n", "<F2>", ":lua require'dap'.step_over()<CR>");
        vim.keymap.set("n", "<F3>", ":lua require'dap'.step_out()<CR>");
        vim.keymap.set("n", "<F5>", ":lua require'dap'.continue()<CR>");
        vim.keymap.set("n", "<leader>b", ":lua require'dap'.toggle_breakpoint()<CR>");
        vim.keymap.set("n", "<leader>B", ":lua require'dap'.set_breakpoint(vim.fn.input('Condition: '))<CR>");

        local dap = require('dap')

        require('dap-go').setup()

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
            args = { '-jar', '/home/irakli/.local/share/nvim/mason/share/java-debug-adapter/com.microsoft.java.debug.plugin-0.47.0.jar' },
        }

        dap.configurations.java = {
            {
                type = 'java',
                request = 'launch',
                name = 'Debug Java Application',
                mainClass = 'io.gcsd.maths.prototyping.prototypes.games.Pyramids',
                program = "${file}",
                stopOnEntry = false,
                cwd = vim.fn.getcwd(),
                classpath = "${workspaceFolder}/target/classes",
                sourcePath = "${workspaceFolder}/src/main/java",
                env = {
                    CLASSPATH = "${workspaceFolder}/target/classes"
                },
            },
        }

        -- dap.configurations.java = {
        --   {
        --     type = 'java',
        --     request = 'launch',
        --     name = 'Debug Java Application',
        --     args = {},
        --     jvmArgs = {},
        --     classPaths = {},
        --     sourcePaths = {},
        --     modulePaths = {},
        --     workspaceFolder = '${workspaceFolder}',
        --   },
        -- }

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
