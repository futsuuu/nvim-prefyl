local owners = {} ---@type table<string, function>

vim.api.nvim_create_autocmd("ColorSchemePre", {
    callback = function(cx)
        local loader = rawget(owners, cx.match)
        if loader then
            loader()
            rawset(owners, cx.match, nil)
        end
    end,
})

---@param plugin_loader function
---@param name string
---@return function
return function(plugin_loader, name)
    rawset(owners, name, plugin_loader)
    return function() end
end
