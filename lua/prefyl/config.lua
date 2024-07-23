---@class prefyl.Config
---@field plugins table<string, prefyl.config.PluginSpec>?

---@class prefyl.config.PluginSpec
---@field url string?
---@field dir string?
---@field enabled boolean?
---@field deps string[]?
---@field cond boolean?
---@field lazy boolean?
---@field cmd string[]?
---@field event string[]?
---@field init function?
---@field config_pre function?
---@field config function?

---@return prefyl.Config
local function load()
    local s, config = pcall(require, "prefyl._config")
    if not s then
        return { plugins = {} }
    end
    if not config.plugins then
        config.plugins = {}
    end
    return config
end

return load()
