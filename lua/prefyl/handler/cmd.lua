---@param plugin_loader function
---@param name string
return function(plugin_loader, name)
    local loaded = false
    vim.api.nvim_create_user_command(name, function(cx)
        loaded = true
        ---@type vim.api.keyset.cmd
        local cmd = {
            cmd = name,
            args = cx.fargs,
            bang = cx.bang,
            count = 0 < cx.count and cx.count or nil,
            mods = cx.smods,
        }
        if cx.range == 1 then
            cmd.range = { cx.line1 }
        elseif cx.range == 2 then
            cmd.range = { cx.line1, cx.line2 }
        end

        vim.api.nvim_del_user_command(name)
        plugin_loader()

        if vim.api.nvim_get_commands({})[name] or vim.api.nvim_buf_get_commands(0, {})[name] then
            print(tostring(cmd.count))
            vim.api.nvim_cmd(cmd, {})
        end
    end, {
        bang = true,
        range = true,
        nargs = "*",
        complete = function(_arglead, cmdline, _cursorpos)
            vim.api.nvim_del_user_command(name)
            plugin_loader()
            return vim.fn.getcompletion(cmdline, "cmdline")
        end,
    })

    return function()
        if not loaded then
            vim.api.nvim_del_user_command(name)
        end
    end
end
