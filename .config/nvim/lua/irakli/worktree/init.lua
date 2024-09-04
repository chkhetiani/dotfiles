local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local actions = require('telescope.actions')
local sorters = require('telescope.sorters')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')
local preview_utils = require('telescope.previewers.utils')
local config = require('telescope.config').values
local path = require('plenary.path'):new()

-- local log = require('plenary.log'):new()
-- log.level = 'debug'

local default_config = {
    show_worktree = {
        create_symlink = true,
        symlink_path = 'current',
    }
}

local user_config = {}

local M = {}

M.setup = function(user_opts)
    user_config = vim.tbl_deep_extend("force", default_config, user_opts or {})
end

M.show_worktree = function(opts)
    local base_path = vim.split(vim.fn.system('git worktree list | grep "(bare)"'), " ")[1] .. '/'

    local worktrees = vim.split(vim.fn.system("git worktree list | awk '{print substr($3, 2, length($3) -2)}'"), "\n")

    pickers.new(opts, {
        finder = finders.new_async_job({
            command_generator = function()
                return { "git", "for-each-ref", "--sort=-committerdate", "--format", "'%(refname:short)'", "refs/heads/" }
            end,
            entry_maker = function(entry)
                entry = entry:sub(2, -2)
                local split = vim.split(entry, " ");
                local name = split[#split]

                -- TODO: if current branch display *
                local pre = '  '
                if vim.tbl_contains(worktrees, entry) then
                    pre = '+ '
                end

                return {
                    value = name,
                    display = pre .. entry,
                    ordinal = entry,
                    dir = name,
                }
            end
        }),
        sorter = config.generic_sorter(opts),
        previewer = previewers.new_buffer_previewer({
            title = "Git branch preview",
            define_preview = function(self, entry)
                local command = {
                    "git",
                    "log",
                    entry.ordinal,
                    "--graph",
                    '--pretty=format:"%h -%d %s (%ar)"',
                    "--abbrev-commit",
                    "--decorate"
                }

                local output = vim.fn.system(table.concat(command, " "))
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, 0, true, vim.split(output, '\n'))
                preview_utils.highlighter(self.state.bufnr, "git")
            end
        }),
        attach_mappings = function(prompt_buffer)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_buffer)

                local cwd = vim.fn.getcwd();
                local bufnr = vim.api.nvim_get_current_buf()
                local current_file = vim.api.nvim_buf_get_name(bufnr)

                local file_without_base = current_file:sub(#cwd + 2);

                local worktree_path = base_path .. selection.dir

                if not path:new(worktree_path):exists() then
                    local command = {
                        "git",
                        "worktree",
                        "add",
                        worktree_path,
                        selection.dir
                    }

                    local _ = vim.fn.system(table.concat(command, " "))
                end

                vim.api.nvim_set_current_dir(worktree_path)

                local p = worktree_path .. "/" .. file_without_base

                local exists = path:new(p):exists()

                if exists then
                    vim.api.nvim_command('edit ' .. p)
                else
                    vim.api.nvim_command('edit ' .. worktree_path)
                end

                if user_config.show_worktree.create_symlink then
                    local function create_symlink(target, link)
                        local link_path = path:new(link)

                        if link_path:exists() then
                            link_path:rm()
                        end

                        local cmd = string.format('ln -s %s %s', vim.fn.shellescape(target), vim.fn.shellescape(link))
                        vim.fn.system(cmd)
                    end

                    create_symlink(worktree_path, (base_path .. user_config.show_worktree.symlink_path))
                end
            end)
            vim.keymap.set({ "i", "v" }, "<c-r>", function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_buffer)

                local command = {
                    "git",
                    "worktree",
                    "remove",
                    selection.ordinal
                }

                local _ = vim.fn.system(table.concat(command, " "))
            end)

            return true
        end
    }):find()
end

-- TODO: add user action to create new worktree from current worktree

return M
