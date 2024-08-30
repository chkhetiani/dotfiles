local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')
local preview_utils = require('telescope.previewers.utils')
local config = require('telescope.config').values

local path = require('plenary.path'):new()

-- local log = require('plenary.log'):new()
-- log.level = 'debug'

local M = {}


M.show_worktree = function(opts)
    pickers.new(opts, {
        finder = finders.new_async_job({
            command_generator = function()
                return { "git", "worktree", "list" }
            end,
            entry_maker = function(entry)
                local split = vim.split(entry, " ");
                local name = split[#split]:sub(2, -2)
                local dir = split[1]
                return {
                    value = entry,
                    display = name,
                    ordinal = name,
                    dir = dir,
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
                    entry.display,
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

                local base = selection.dir:sub(0, #selection.dir - #selection.display)

                vim.api.nvim_set_current_dir(selection.dir)

                local p = selection.dir .. "/" .. file_without_base

                local exists = path:new(p):exists()

                if exists then
                    vim.api.nvim_command('edit ' .. p)
                else
                    vim.api.nvim_command('edit ' .. selection.dir)
                end

                local function create_symlink(target, link)
                    local link_path = path:new(link)

                    if link_path:exists() then
                        link_path:rm()
                    end

                    local cmd = string.format('ln -s %s %s', vim.fn.shellescape(target), vim.fn.shellescape(link))
                    vim.fn.system(cmd)
                end

                create_symlink(selection.dir, (base .. 'current'))
            end)
            return true
        end
    }):find()
end

-- TODO: new worktree
-- TODO: add keymap for remove worktree

vim.keymap.set("n", "<leader>wt", function() M.show_worktree({}) end, { desc = "show [W]ork[t]rees" })

return M
