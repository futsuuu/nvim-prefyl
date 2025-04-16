local owners = {} ---@type table<string, function>

vim.api.nvim_create_autocmd("ColorSchemePre", {
    callback = function(cx)
        local loader = owners[cx.match]
        if loader then
            loader()
            owners[cx.match] = nil
        end
    end,
})

---@param plugin_loader function
---@param name string
---@return function?
return function(plugin_loader, name)
    owners[name] = plugin_loader
end
