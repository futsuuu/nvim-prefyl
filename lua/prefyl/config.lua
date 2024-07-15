local M = {}

---@class prefyl.Config
---@field plugins table<string, prefyl.config.PluginSpec>?

---@class prefyl.ConfigWithDefault
---@field plugins table<string, prefyl.config.PluginSpecWithDefault>

---@type prefyl.ConfigWithDefault
local default_config = {
    plugins = {},
}

---@class prefyl.config.PluginSpec
---@field url string?
---@field dir string?
---@field enabled boolean?
---@field deps string[]?
---@field cond boolean?
---@field lazy boolean?
---@field cmd string[]?
---@field init function?
---@field config_pre function?
---@field config function?

---@class prefyl.config.PluginSpecWithDefault
---@field url string?
---@field dir string?
---@field enabled boolean
---@field deps string[]
---@field cond boolean
---@field lazy boolean?
---@field cmd string[]?
---@field init function
---@field config_pre function
---@field config function

local function f() end

---@type prefyl.config.PluginSpecWithDefault
local default_plugin_spec = {
    cond = true,
    enabled = true,
    deps = {},
    init = f,
    config_pre = f,
    config = f,
}

---@return prefyl.ConfigWithDefault
function M.load()
    local config = package.loaded["prefyl._config"]
    if config then
        return config
    end
    local s, config = pcall(require, "prefyl._config")
    if not s then
        return default_config
    end

    config = vim.tbl_extend("keep", config, default_config)
    for name, spec in pairs(config.plugins) do
        config.plugins[name] = vim.tbl_extend("keep", spec, default_plugin_spec)
    end
    package.loaded["prefyl._config"] = config
    return config
end

return M
