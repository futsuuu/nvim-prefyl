local Path = require("prefyl.lib.path")

---@class prefyl.compiler.Config
---@field plugins table<string, prefyl.compiler.config.PluginSpec>

---@class prefyl.compiler.config.PluginSpec
---@field url string?
---@field dir prefyl.Path
---@field enabled boolean
---@field deps string[]
---@field lazy boolean
---@field cmd string[]?

local PLUGIN_ROOT = Path.stdpath.data / "prefyl" / "plugins"

---@return prefyl.compiler.Config
local function load()
    local config = require("prefyl.config")

    vim.validate({
        config = { config, { "t" } },
    })
    vim.validate({
        plugins = { config.plugins, { "t" } },
    })
    for name, spec in pairs(config.plugins) do
        ---@cast spec prefyl.config.PluginSpec
        vim.validate({
            name = { name, "s" },
            [name] = { spec, "t" },
        })
        vim.validate({
            url = { spec.url, { "s", "nil" } },
            dir = { spec.dir, { "s", "nil" } },
            enabled = { spec.enabled, { "b", "nil" } },
            deps = { spec.deps, { "t", "nil" } },
            cond = { spec.cond, { "b", "nil" } },
            lazy = { spec.lazy, { "b", "nil" } },
            cmd = { spec.cmd, { "t", "nil" } },
            init = { spec.init, { "f", "nil" } },
            config_pre = { spec.config_pre, { "f", "nil" } },
            config = { spec.config, { "f", "nil" } },
        })
    end

    ---@type prefyl.compiler.Config
    local compiler_config = {
        plugins = {},
    }
    for name, spec in pairs(config.plugins) do
        local cmd = spec.cmd or {}
        local lazy = spec.lazy
        if lazy == nil then
            lazy = 0 < #cmd
        end
        ---@type prefyl.compiler.config.PluginSpec
        compiler_config.plugins[name] = {
            dir = spec.dir and Path.new(spec.dir) or (PLUGIN_ROOT / name),
            url = spec.url,
            deps = spec.deps or {},
            enabled = spec.enabled ~= false,
            lazy = lazy,
            cmd = cmd,
        }
    end

    return compiler_config
end

return load()
