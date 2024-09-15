---@param plugin_loader function
---@param name string
---@return function
return function(plugin_loader, name)
    local loaded = false

    vim.api.nvim_create_user_command(name, function(cx)
        ---@type vim.api.keyset.cmd
        local cmd = {
            cmd = name,
            args = cx.fargs,
            bang = cx.bang,
            mods = cx.smods,
        }
        if 0 < cx.count then
            cmd.count = cx.count
        end
        if cx.range == 1 then
            cmd.range = { cx.line1 }
        elseif cx.range == 2 then
            cmd.range = { cx.line1, cx.line2 }
        end

        loaded = true
        vim.api.nvim_del_user_command(name)
        plugin_loader()

        if
            rawget(vim.api.nvim_get_commands({}), name) ~= nil
            or rawget(vim.api.nvim_buf_get_commands(0, {}), name) ~= nil
        then
            vim.api.nvim_cmd(cmd, {})
        end
    end, {
        bang = true,
        range = true,
        nargs = "*",
        complete = function(_arglead, cmdline, _cursorpos)
            loaded = true
            vim.api.nvim_del_user_command(name)
            plugin_loader()
            return vim.api.nvim_call_function("getcompletion", { cmdline, "cmdline" })
        end,
    })

    return function()
        if not loaded then
            vim.api.nvim_del_user_command(name)
        end
    end
end
