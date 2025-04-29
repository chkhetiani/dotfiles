local M = {};

M.open = function()
    local path = vim.loop.cwd() .. '/stats';
    if vim.ui.open then
        local rv, msg = vim.ui.open(path)
        return
    end

    local cmd = { "xdg-open", path };

    local rv = vim.system(cmd, { text = true, detach = true }):wait()
    if rv.code ~= 0 then
        local msg = ('vim.ui.open: command failed (%d): %s'):format(rv.code, vim.inspect(cmd))
        return rv, msg
    end
end

return M;
