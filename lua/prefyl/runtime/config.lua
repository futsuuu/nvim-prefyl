---@class prefyl._runtime
---@field plugins? table<string, prefyl._runtime.Plugin>

---@class prefyl._runtime.Plugin
---@field cond? boolean
---@field init? fun()
---@field config_pre? fun()
---@field config? fun()

---@type boolean, prefyl._runtime
local s, config = pcall(require, "prefyl._runtime")
if not s then
    ---@type prefyl._runtime
    return {
        plugins = {},
    }
end
if config.plugins == nil then
    config.plugins = {}
end
return config
