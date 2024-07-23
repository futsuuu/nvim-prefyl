local M = {}

-- key: plugin name
---@type table<string, function>
local plugin_loaders = {}
-- key: plugin name
---@type table<string, function[]>
local handler_interrupters = {}

---@param plugin_name string?
function M.load_plugin(plugin_name)
    local loader = rawget(plugin_loaders, plugin_name)
    if not loader then
        return
    end
    rawset(plugin_loaders, plugin_name, nil)
    for _, f in ipairs(rawget(handler_interrupters, plugin_name) or {}) do
        f()
    end
    loader()
end

---@param plugin_name string
---@param loader function
function M.set_plugin_loader(plugin_name, loader)
    rawset(plugin_loaders, plugin_name, loader)
end

-- key: module name
-- val: binary chunk
---@type table<string, string>
local luachunks = {}
-- key: module name
-- val: plugin name
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

---@param plugin_name string?
---@return function
local function get_plugin_loader(plugin_name)
    return function()
        M.load_plugin(plugin_name)
    end
end

---@param plugin_name string
---@param fn function?
local function insert_handler_interrupter(plugin_name, fn)
    if not fn then
        return
    end
    local interrupters = rawget(handler_interrupters, plugin_name)
    if interrupters then
        table.insert(interrupters, fn)
    else
        rawset(handler_interrupters, plugin_name, { fn })
    end
end

local colorscheme_handler ---@module "prefyl.handler.colorscheme"
---@param plugin_name string
---@param colorscheme string
function M.handle_colorscheme(plugin_name, colorscheme)
    colorscheme_handler = colorscheme_handler or require("prefyl.handler.colorscheme")
    insert_handler_interrupter(
        plugin_name,
        colorscheme_handler(get_plugin_loader(plugin_name), colorscheme)
    )
end

local user_command_handler ---@module "prefyl.handler.cmd"
---@param plugin_name string
---@param user_command string
function M.handle_user_command(plugin_name, user_command)
    user_command_handler = user_command_handler or require("prefyl.handler.cmd")
    insert_handler_interrupter(
        plugin_name,
        user_command_handler(get_plugin_loader(plugin_name), user_command)
    )
end

local event_handler ---@module "prefyl.handler.event"
---@param plugin_name string
---@param event string | string[]
---@param pattern (string | string[])?
function M.handle_event(plugin_name, event, pattern)
    event_handler = event_handler or require("prefyl.handler.event")
    insert_handler_interrupter(
        plugin_name,
        event_handler(get_plugin_loader(plugin_name), event, pattern)
    )
end

return M
