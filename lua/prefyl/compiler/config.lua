local Path = require("prefyl.lib.path")

local M = {}

---@class prefyl.compiler.Config
---@field plugins table<string, prefyl.compiler.config.PluginSpec>

---@class prefyl.compiler.config.PluginSpec
---@field url string?
---@field dir prefyl.Path
---@field enabled boolean
---@field deps string[]

local PLUGIN_ROOT = Path.stdpath.data / "prefyl" / "plugins"

---@return prefyl.compiler.Config
function M.load()
    local config = require("prefyl.config").load()

    vim.validate({
        config = { config, { "t" } },
    })
    vim.validate({
        plugins = { config.plugins, { "t" } },
    })
    for name, spec in pairs(config.plugins) do
        ---@cast spec prefyl.config.PluginSpecWithDefault
        vim.validate({
            name = { name, "s" },
            [name] = { spec, "t" },
        })
        vim.validate({
            url = { spec.url, { "s", "nil" } },
            dir = { spec.dir, { "s", "nil" } },
            cond = { spec.cond, { "b" } },
            enabled = { spec.enabled, { "b" } },
            deps = { spec.deps, { "t" } },
            init = { spec.init, { "f" } },
            config_pre = { spec.config_pre, { "f" } },
            config = { spec.config, { "f" } },
        })
    end

    ---@type prefyl.compiler.Config
    local compiler_config = {
        plugins = {},
    }
    for name, spec in pairs(config.plugins) do
        ---@type prefyl.compiler.config.PluginSpec
        compiler_config.plugins[name] = {
            dir = spec.dir and Path.new(spec.dir) or (PLUGIN_ROOT / name),
            url = spec.url,
            deps = spec.deps,
            enabled = spec.enabled,
        }
    end

    return compiler_config
end

return M
