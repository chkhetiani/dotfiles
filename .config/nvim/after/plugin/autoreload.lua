local function scroll_to_end(bufnr)
    local cur_win = vim.api.nvim_get_current_win()

    -- switch to buf and set cursor
    vim.api.nvim_buf_call(bufnr, function()
        local target_win = vim.api.nvim_get_current_win()
        vim.api.nvim_set_current_win(target_win)

        local target_line = vim.tbl_count(vim.api.nvim_buf_get_lines(0, 0, -1, true))
        vim.api.nvim_win_set_cursor(target_win, { target_line, 0 })
    end)

    -- return to original window
    vim.api.nvim_set_current_win(cur_win)
end

local attach_to_buffer = function(output_bufnr, pattern, command)
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = vim.api.nvim_create_augroup("my_autosave", { clear = true }),
        pattern = pattern,
        callback = function()
            local append_data = function(_, data)
                if data then
                    vim.api.nvim_buf_set_lines(output_bufnr, -1, -1, false, data)
                    scroll_to_end(output_bufnr)
                end
            end

            -- kill the process
            pcall(os.execute, "kill $(lsof -n -i :8080 | grep java | awk '{print $2}') > /dev/null 2>&1")

            -- highlight errors
            vim.api.nvim_buf_call(output_bufnr, function() vim.cmd(":match Error /.*ERROR.*/") end)

            -- start the server
            Auto_Run_Job_ID = vim.fn.jobstart(command, {
                -- stdout_buffered = true,
                on_stdout = append_data,
                on_stderr = append_data
            })
        end
    })
end

-- attach_to_buffer(15, "*java", { "mvn", "jetty:run", "-f", "games/pom.xml" })

vim.api.nvim_create_user_command("AutoRun", function()
    local bufnr = tonumber(vim.api.nvim_get_current_buf())
    local pattern = vim.fn.input "Pattern: "
    local command_str = vim.fn.input "Command: "

    local function isempty(s)
        return s == nil or s == ''
    end

    if isempty(pattern) then
        pattern = "*.java"
    end
    if isempty(command_str) then
        command_str = "mvn jetty:run -f games/pom.xml"
    end

    local command = vim.split(command_str, " ")

    attach_to_buffer(bufnr, pattern, command)
end, {})
