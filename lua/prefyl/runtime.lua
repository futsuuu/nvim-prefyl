local M = {}

local plugin_loaders = {} ---@type table<string, function>

---@param plugin_name string?
function M.load_plugin(plugin_name)
    local loader = rawget(plugin_loaders, plugin_name)
    if loader then
        rawset(plugin_loaders, plugin_name, nil)
        loader()
    end
end

---@param plugin_name string
---@param loader function
function M.set_plugin_loader(plugin_name, loader)
    rawset(plugin_loaders, plugin_name, loader)
end

---key: module name
---val: binary chunk
---@type table<string, string>
local luachunks = {}
---key: module name
---val: plugin name
---@type table<string, string>
local luamodule_owners = {}

---@param module_name string
---@return string | function
table.insert(package.loaders, 2, function(module_name)
    M.load_plugin(rawget(luamodule_owners, module_name))
    local chunk = rawget(luachunks, module_name)
    if not chunk then
        return "\n\tno cache '" .. module_name .. "'"
    end
    local chunk, err = loadstring(chunk)
    return chunk or ("\n\t" .. err)
end)

---@param module_name string
---@param chunk string
function M.set_luachunk(module_name, chunk)
    rawset(luachunks, module_name, chunk)
end

---@param plugin_name string
---@param module_name string
function M.handle_luamodule(plugin_name, module_name)
    rawset(luamodule_owners, module_name, plugin_name)
end

return M
