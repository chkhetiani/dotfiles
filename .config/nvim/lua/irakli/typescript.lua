local M = {}

local function setup_keymaps(bufnr)
    local map = function(mode, keys, func, desc)
        vim.keymap.set(mode, keys, func, { buffer = bufnr, desc = 'TS: ' .. desc })
    end

    map('n', '<leader>gi', '<Cmd>TSToolsOrganizeImports<CR>', 'Organize Imports')
    map('n', '<leader>gm', '<Cmd>TSToolsAddMissingImports<CR>', 'Add Missing Imports')

    map('n', '<leader>gj', function()
        local root = vim.fs.root(bufnr, 'tsconfig.json') or vim.fn.getcwd()
        local tsconfig = root .. '/tsconfig.json'
        local tsc = root .. '/node_modules/.bin/tsc'
        if vim.fn.executable(tsc) == 0 then tsc = 'tsc' end

        vim.cmd('compiler tsc')   -- buffer-local errorformat from $VIMRUNTIME/compiler/tsc.vim
        local args = ' --noEmit --pretty false'
        if vim.fn.filereadable(tsconfig) == 1 then
            args = args .. ' -p ' .. vim.fn.shellescape(tsconfig)
        end
        vim.opt_local.makeprg = tsc .. args
        vim.cmd('silent make!')
        vim.cmd('copen')
    end, 'Typecheck (tsc --noEmit)')
end

function M.Init()
    vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'typescript', 'typescriptreact', 'javascript', 'javascriptreact' },
        callback = function(event) setup_keymaps(event.buf) end,
    })
    return true
end

return M
