return {
	"mfussenegger/nvim-dap",
	dependencies = {
		-- 'rcarriga/nvim-dap-ui',
		"mfussenegger/nvim-jdtls",
		"theHamsta/nvim-dap-virtual-text",
		"nvim-neotest/nvim-nio"
		-- 'leoluz/nvim-dap-go',
	},
	config = function()
		vim.keymap.set("n", "<F1>", function()
			require("dap").step_into()
		end)
		vim.keymap.set("n", "<F2>", function()
			require("dap").step_over()
		end)
		vim.keymap.set("n", "<F3>", function()
			require("dap").step_out()
		end)
		vim.keymap.set("n", "<F5>", function()
			require("dap").continue()
		end)
		vim.keymap.set("n", "<leader>b", function()
			require("dap").toggle_breakpoint()
		end)
		vim.keymap.set("n", "<leader>B", function()
			require("dap").set_breakpoint(vim.fn.input("Condition: "))
		end)

		local dap = require("dap")
		dap.set_log_level("DEBUG")

		-- Define the highlight groups with colors
		vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#e51400" }) -- red
		vim.api.nvim_set_hl(0, "DapBreakpointCondition", { fg = "#f5c242" }) -- yellow/orange
		vim.api.nvim_set_hl(0, "DapBreakpointRejected", { fg = "#808080" }) -- gray
		vim.api.nvim_set_hl(0, "DapStopped", { fg = "#98c379" }) -- green
		vim.api.nvim_set_hl(0, "DapLogPoint", { fg = "#61afef" }) -- blue

		local dap_signs = {
			DapBreakpoint = { text = "⬤", texthl = "DapBreakpoint" },
			DapBreakpointCondition = { text = "⬣", texthl = "DapBreakpointCondition" },
			DapBreakpointRejected = { text = "✖", texthl = "DapBreakpointRejected" },
			DapStopped = { text = "▶", texthl = "DapStopped" },
			DapLogPoint = { text = "◉", texthl = "DapLogPoint" },
		}

		for sign_name, sign_config in pairs(dap_signs) do
			vim.fn.sign_define(sign_name, sign_config)
		end

		vim.keymap.set("n", "<space>gb", dap.run_to_cursor)

		-- Eval var under cursor
		vim.keymap.set("n", "<space>?", function()
			require("dap.ui.widgets").hover()
		end)

		vim.keymap.set("n", "<space>dw", function()
			require("dap-view").add_expr()
		end)

		dap.adapters.coreclr = {
			type = "executable",
			command = "/home/irakli/.local/share/nvim/mason/bin/netcoredbg",
			args = { "--interpreter=vscode" },
		}

		dap.configurations.cs = {
			{
				type = "coreclr",
				name = "launch - netcoredbg",
				request = "launch",
				program = function()
					return vim.fn.input("Path to dll", vim.fn.getcwd() .. "/bin/Debug/", "file")
				end,
			},
		}
		dap.adapters.java = function(callback, config)
			-- Check if jdtls is running
			local clients = vim.lsp.get_clients({ name = "jdtls", bufnr = 0 })
			if #clients == 0 then
				return
			end

			vim.lsp.buf_request(0, "workspace/executeCommand", {
				command = "vscode.java.startDebugSession",
				arguments = {},
			}, function(err, result)
				if err then
					return
				end

				if type(result) == "number" then
					callback({
						type = "server",
						host = "127.0.0.1",
						port = result,
					})
				elseif type(result) == "table" then
					callback({
						type = "server",
						host = result.host or "127.0.0.1",
						port = result.port,
					})
				else
					print("=== Unexpected result type:", type(result), vim.inspect(result), "===")
				end
			end)
		end

		dap.configurations.java = {
			{
				type = "java",
				request = "attach",
				name = "Attach to Jetty",
				hostName = "127.0.0.1",
				port = 5005,
			},
		}

		dap.adapters.delve = {
			type = "server",
			port = "${port}",
			executable = {
				command = "dlv",
				args = { "dap", "-l", "127.0.0.1:${port}" },
			},
		}

		-- https://github.com/go-delve/delve/blob/master/Documentation/usage/dlv_dap.md
		dap.configurations.go = {
			{
				type = "delve",
				name = "Debug .",
				request = "launch",
				program = ".",
			},
			{
				type = "delve",
				name = "Debug",
				request = "launch",
				program = "${file}",
			},
			{
				type = "delve",
				name = "Debug test", -- configuration for debugging test files
				request = "launch",
				mode = "test",
				program = "${file}",
			},
			-- works with go.mod packages and sub packages
			{
				type = "delve",
				name = "Debug test (go.mod)",
				request = "launch",
				mode = "test",
				program = "./${relativeFileDirname}",
			},
		}

		require("nvim-dap-virtual-text").setup({
			-- This just tries to mitigate the chance that I leak tokens here. Probably won't stop it from happening...
			display_callback = function(variable)
				local name = string.lower(variable.name)
				local value = string.lower(variable.value)
				if name:match("secret") or name:match("api") or value:match("secret") or value:match("api") then
					return "*****"
				end

				if #variable.value > 15 then
					return " " .. string.sub(variable.value, 1, 15) .. "... "
				end

				return " " .. variable.value
			end,
		})

		local dapview = require("dap-view")

		dap.listeners.after.event_initialized["dapui_config"] = function()
			dapview.open()
		end
		dap.listeners.after.event_terminated["dapui_config"] = function()
			dapview.close()
		end
		dap.listeners.after.event_exited["dapui_config"] = function()
			dapview.close()
		end
	end,
}
