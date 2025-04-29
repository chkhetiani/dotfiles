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
        layout_config = {
            width = 0.33,
        },
        sorter = config.generic_sorter(opts),
        -- previewer = previewers.new_buffer_previewer({
        --     title = "Git branch preview",
        --     define_preview = function(self, entry)
        --         local command = {
        --             "git",
        --             "log",
        --             entry.ordinal,
        --             "--graph",
        --             '--pretty=format:"%h -%d %s (%ar)"',
        --             "--abbrev-commit",
        --             "--decorate"
        --         }
        --
        --         local output = vim.fn.system(table.concat(command, " "))
        --         vim.api.nvim_buf_set_lines(self.state.bufnr, 0, 0, true, vim.split(output, '\n'))
        --         preview_utils.highlighter(self.state.bufnr, "git")
        --     end
        -- }),
        attach_mappings = function(prompt_buffer)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_buffer)
                M.change_worktree(base_path, selection.dir);
            end)
            -- vim.keymap.set({ "i", "v" }, "<c-r>", function()
            --     local selection = action_state.get_selected_entry()
            --     actions.close(prompt_buffer)
            --
            --     local command = {
            --         "git",
            --         "worktree",
            --         "remove",
            --         selection.ordinal
            --     }
            --
            --     local _ = vim.fn.system(table.concat(command, " "))
            -- end)

            return true
        end
    }):find()
end

M.change_worktree = function(base_path, worktree_name)
    local cwd = vim.loop.cwd();
    local bufnr = vim.api.nvim_get_current_buf()
    local current_file = vim.api.nvim_buf_get_name(bufnr)

    print(cwd)
    if cwd == nil then
        cwd = vim.fn.getcwd()
    end
    print(cwd)

    local file_without_base = current_file:sub(#cwd + 2);

    local worktree_path = base_path .. worktree_name

    if not path:new(worktree_path):exists() then
        local command = {
            "git",
            "worktree",
            "add",
            worktree_path,
            worktree_name
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
end

M.create_worktree = function(base_path, branch)
    local worktree_path = "../" .. branch
    local existing_path = path:new(worktree_path)

    if existing_path:exists() and not user_config.new_worktree.force then
        vim.notify("Directory already exists. Use force option to overwrite.", "error")
        return
    end

    if existing_path:exists() and user_config.new_worktree.force then
        existing_path:rmdir_p()
    end
    local command = {
        "git",
        "worktree",
        "add",
        "-b",
        branch,
        worktree_path,
    }

    local result = vim.fn.system(table.concat(command, " "))

    if vim.v.shell_error ~= 0 then
        vim.notify("Failed to create worktree: " .. result, "error")
        return
    end

    M.change_worktree(base_path, branch)
end

M.remove_worktree = function(base_path, worktree_name)
    local worktree_path = base_path .. worktree_name
    local existing_path = path:new(worktree_path)
    if not existing_path:exists() then
        vim.notify("Worktree directory does not exist.", "error")
        return
    end

    local command = {
        "git",
        "worktree",
        "remove",
        worktree_path,
        "--force", -- Force removal even if the worktree is linked
    }
    local result = vim.fn.system(table.concat(command, " "))

    local command2 = {
        "git",
        "branch",
        "-D",
        worktree_name,
    }
    local result2 = vim.fn.system(table.concat(command2, " "))

    if vim.v.shell_error ~= 0 then
        vim.notify("Failed to remove worktree: " .. result, "error")
        return
    end

    if user_config.show_worktree.create_symlink then
        local symlink_path = path:new(base_path .. user_config.show_worktree.symlink_path)
        if symlink_path:exists() and symlink_path:readlink() == worktree_path then
            symlink_path:rm()
        end
    end

    vim.notify("Worktree '" .. worktree_name .. "' removed.", "success")
end

vim.api.nvim_create_user_command("WorkTreeCreate", function()
    local base_path = vim.split(vim.fn.system('git worktree list | grep "(bare)"'), " ")[1] .. '/'
    local branch = vim.fn.input("Enter branch name: ")

    if branch == "" then
        vim.notify("Worktree name is required", "error")
        return
    end

    local worktree = require("irakli.worktree")
    worktree.create_worktree(base_path, branch)
end, { nargs = 1, desc = "Create a new git worktree" })

vim.api.nvim_create_user_command("WorkTreeRemove", function()
    local base_path = vim.split(vim.fn.system('git worktree list | grep "(bare)"'), " ")[1] .. '/'
    local branch = vim.fn.input("Enter branch name: ")

    if branch == "" then
        vim.notify("Worktree name is required", "error")
        return
    end

    M.remove_worktree(base_path, branch)
    M.change_worktree(base_path, 'master')
end, { nargs = 1, desc = "Remove a git worktree" })

return M
