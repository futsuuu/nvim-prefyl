local group = vim.api.nvim_create_augroup('prefyl_handler', {})

local existing_augroups = {} ---@type table<integer, true>
local existing_autocmds = {} ---@type table<integer, true>

---@param plugin_loader function
local function callback(cx, plugin_loader)
    for _, au in ipairs(vim.api.nvim_get_autocmds({ event = cx.event })) do
        if au.id then
            rawset(existing_autocmds, au.id, true)
        end
        if au.group then
            rawset(existing_augroups, au.group, true)
        end
    end

    plugin_loader()

    for _, au in ipairs(vim.api.nvim_get_autocmds({ event = cx.event })) do
        if
            au.group
            and not rawget(existing_augroups, au.group)
            and not rawget(existing_autocmds, au.id)
        then
            vim.api.nvim_exec_autocmds(cx.event, {
                group = au.group,
                pattern = au.pattern,
                buffer = au.buffer,
                data = cx.data,
                modeline = false,
            })
        end
    end
end

---@param plugin_loader function
---@param event string | string[]
---@param pattern (string | string[])?
---@return function
return function(plugin_loader, event, pattern)
    local id = vim.api.nvim_create_autocmd(event, {
        pattern = pattern,
        once = true,
        group = group,
        callback = function(cx)
            callback(cx, plugin_loader)
        end,
    })

    return function()
        vim.api.nvim_del_autocmd(id)
    end
end
