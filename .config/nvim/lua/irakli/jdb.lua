local M = {}
M.breakpoints = {}
M.jdb_job = nil
M.jdb_buf = nil
M.debug_port = 5005

local function current_pos()
    return vim.fn.expand("%:p"), vim.fn.line(".")
end

local function get_fqcn(file)
    local class_name = vim.fn.fnamemodify(file, ":t:r")
    local pkg_name = nil
    local lines = vim.fn.readfile(file)
    for _, line in ipairs(lines) do
        line = vim.trim(line)
        if line:match("^package%s+") then
            pkg_name = line:match("^package%s+([%w%.]+);")
            break
        end
    end
    if pkg_name then
        return pkg_name .. "." .. class_name
    else
        return class_name
    end
end

local function create_jdb_buf()
    M.jdb_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(M.jdb_buf, "JDB Output")
    vim.bo[M.jdb_buf].bufhidden = "wipe"
    vim.bo[M.jdb_buf].filetype = "jdb"


    local total_lines = vim.o.lines
    local height = math.floor(total_lines * 0.25)
    vim.cmd("botright " .. height .. "split")
    vim.api.nvim_win_set_buf(0, M.jdb_buf)
end

local function append_to_buf(line)
    local function remove_prefix(str, prefix)
        if str:sub(1, #prefix) == prefix then
            return str:sub(#prefix + 1)
        else
            return str
        end
    end

    if M.jdb_buf and vim.api.nvim_buf_is_valid(M.jdb_buf) then
        line = remove_prefix(line, "[jdb]")
        vim.api.nvim_buf_set_lines(M.jdb_buf, -1, -1, false, { line })
        vim.api.nvim_buf_call(M.jdb_buf, function()
            vim.cmd("normal! G")
        end)
    end
end

function M.toggle_breakpoint()
    local file, line = current_pos()
    local key = file .. ":" .. line

    if M.breakpoints[key] then
        M.breakpoints[key] = nil
        append_to_buf("Removed breakpoint " .. key)
    else
        M.breakpoints[key] = true
        append_to_buf("Added breakpoint " .. key)
    end

    if M.jdb_job then
        local class = get_fqcn(file)
        local cmd = "stop at " .. class .. ":" .. line .. "\n"
        vim.api.nvim_chan_send(M.jdb_job, cmd)
        append_to_buf("Sent breakpoint to jdb: " .. cmd)
    end
end

function M.attach_jdb()
    if M.jdb_job then
        append_to_buf("jdb already attached")
        return
    end

    create_jdb_buf()

    local args = { "jdb", "-attach", "127.0.0.1:" .. M.debug_port }
    M.jdb_job = vim.fn.jobstart(args, {
        stdout_buffered = false,
        stderr_buffered = false,
        on_stdout = function(_, data)
            M.handle_jdb_output(data)
            if data then
                for _, line in ipairs(data) do
                    if line ~= "" then append_to_buf("[jdb] " .. line) end
                end
            end
        end,
        on_stderr = function(_, data)
            if data then
                for _, line in ipairs(data) do
                    if line ~= "" then append_to_buf("[jdb-err] " .. line) end
                end
            end
        end,
        on_exit = function(_, code)
            append_to_buf("jdb exited with code " .. code)
            M.jdb_job = nil
            if M.jdb_buf and vim.api.nvim_buf_is_valid(M.jdb_buf) then
                vim.api.nvim_buf_delete(M.jdb_buf, { force = true })
                M.jdb_buf = nil
            end
        end,
    })

    append_to_buf("Attached jdb to port " .. M.debug_port)

    vim.defer_fn(function()
        vim.api.nvim_chan_send(M.jdb_job, "cont\n")
        for key, _ in pairs(M.breakpoints) do
            local file, line = key:match("(.+):(%d+)")
            local class = get_fqcn(file)
            local cmd = "stop at " .. class .. ":" .. line .. "\n"
            vim.api.nvim_chan_send(M.jdb_job, cmd)
        end
    end, 500)
end

function M.send_command()
    if not M.jdb_job then
        print("No jdb attached")
        return
    end
    vim.ui.input({ prompt = "jdb command: " }, function(input)
        if input and #input > 0 then
            vim.api.nvim_chan_send(M.jdb_job, input .. "\n")
            append_to_buf("> " .. input)
        end
    end)
end

function M.detach_jdb()
    if M.jdb_job then
        vim.fn.jobstop(M.jdb_job)
        M.jdb_job = nil
    end
    if M.jdb_buf and vim.api.nvim_buf_is_valid(M.jdb_buf) then
        vim.api.nvim_buf_delete(M.jdb_buf, { force = true })
        M.jdb_buf = nil
    end
    print("Detached jdb")
end

function M.print_json_under_cursor()
    if vim.bo.filetype ~= "java" then
        return
    end
    if not M.jdb_job then
        print("No jdb attached")
        return
    end

    local var = vim.fn.expand("<cword>")
    if var == "" then
        print("No variable under cursor")
        return
    end

    local cmd = "print new com.google.gson.GsonBuilder().setPrettyPrinting().create().toJson(" .. var .. ")"
    vim.api.nvim_chan_send(M.jdb_job, cmd .. "\n")
end

function M.handle_jdb_output(data)
    if not data then return end
    for _, line in ipairs(data) do
        if line:match("line=(%d+)") then
            local lineno = tonumber(line:match("line=(%d+)"))
            local file = vim.fn.expand("%:p") -- simplify: current file
            -- move cursor to current line
            vim.api.nvim_win_set_cursor(0, { lineno, 0 })
            -- optionally highlight line
            vim.cmd("normal! zz")
        end
    end
end


vim.keymap.set("n", "<leader>da", function() M.attach_jdb() end, { desc = "Attach jdb" })
vim.keymap.set("n", "<leader>dd", function() M.detach_jdb() end, { desc = "Detach jdb" })
vim.keymap.set("n", "<leader>db", function() M.toggle_breakpoint() end, { desc = "Toggle breakpoint" })
vim.keymap.set("n", "<leader>dc", function() M.send_command() end, { desc = "Send command to jdb" })

local function map_jdb_commands()
    vim.keymap.set("n", "<leader>?", function()
        require("irakli.jdb").print_json_under_cursor()
    end, { desc = "Print variable as pretty JSON", buffer = true, remap = true })

    local opts = { buffer = true, remap = true }

    vim.keymap.set("n", "<F5>", function()
        vim.api.nvim_chan_send(M.jdb_job, "cont\n")
    end, opts)

    vim.keymap.set("n", "<F1>", function()
        vim.api.nvim_chan_send(M.jdb_job, "step\n")
    end, opts)

    vim.keymap.set("n", "<F2>", function()
        vim.api.nvim_chan_send(M.jdb_job, "next\n")
    end, opts)


    vim.keymap.set("n", "<F3>", function()
        vim.api.nvim_chan_send(M.jdb_job, "step up\n")
    end, opts)
end

vim.api.nvim_create_autocmd("FileType", {
    pattern = "java",
    callback = function()
        map_jdb_commands()
    end,
})

return M
