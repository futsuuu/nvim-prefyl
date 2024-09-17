local group = vim.api.nvim_create_augroup("prefyl_handler", {})

local augroups = {} ---@type table<integer, true>
local autocmds = {} ---@type table<integer, true>

---@param plugin_loader function
local function callback(cx, plugin_loader)
    for _, au in ipairs(vim.api.nvim_get_autocmds({ event = cx.event })) do
        if au.id ~= nil then
            rawset(autocmds, au.id, true)
        end
        if au.group ~= nil then
            rawset(augroups, au.group, true)
        end
    end

    plugin_loader()

    for _, au in ipairs(vim.api.nvim_get_autocmds({ event = cx.event })) do
        if
            au.group ~= nil
            and rawget(augroups, au.group) == nil
            and rawget(autocmds, au.id) == nil
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
