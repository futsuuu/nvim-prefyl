local Path = require("prefyl.lib.Path")
local str = require("prefyl.lib.str")

local Chunk = require("prefyl.build.Chunk")
local Config = require("prefyl.build.Config")
local Out = require("prefyl.build.Out")
local Plugin = require("prefyl.build.Plugin")
local RuntimeDir = require("prefyl.build.RuntimeDir")
local dump = require("prefyl.build.dump")
local installer = require("prefyl.build.installer")
local nvim = require("prefyl.build.nvim")
local runtime = require("prefyl.build.runtime")

local M = {}

local default_runtimepaths = nvim.default_runtimepaths()

---@param out prefyl.build.Out
---@param config prefyl.build.Config
---@return string
local function generate_script(out, config)
    local runtime_file = Path.prefyl_root / "lua" / "prefyl" / "runtime.lua"
    local s = str.dedent([[
    rawset(package.preload, "prefyl.runtime", loadstring(%q, %q))
    vim.api.nvim_set_var("did_load_ftdetect", 1)
    vim.api.nvim_set_option_value("loadplugins", false, {})
    vim.api.nvim_set_option_value("packpath", %q, {})
    ]]):format(
        dump(runtime_file, true),
        runtime_file:chunkname(),
        vim.iter(nvim.default_packpaths()):map(tostring):join(",")
    )

    s = s
        .. Plugin.new_std(config.std, vim.iter(default_runtimepaths):map(RuntimeDir.new):totable())
            :initialize(out)
            :tostring()

    ---@type table<string, prefyl.build.Plugin>
    local plugins = vim.iter(config.plugins)
        :filter(function(_name, spec) ---@param spec prefyl.build.Config.PluginSpec
            return not vim.list_contains(default_runtimepaths, spec.dir)
        end)
        :fold({}, function(acc, name, spec) ---@param spec prefyl.build.Config.PluginSpec
            acc[name] = Plugin.new(spec)
            return acc
        end)

    local scope = Chunk.scope()

    for _, plugin in pairs(plugins) do
        scope:push(plugin:initialize(out))
    end

    scope:extend(vim.iter(plugins)
        :filter(function(_name, plugin) ---@param plugin prefyl.build.Plugin
            return not plugin:is_lazy()
        end)
        :map(function(name, _plugin)
            return runtime.load_plugin(name)
        end)
        :totable())

    s = s .. scope:to_chunk():tostring()

    return s
end

---@param strip boolean
---@return prefyl.Path
function M.build(strip)
    local config = Config.load(default_runtimepaths)
    local out = Out.new(strip)

    installer.install(config)
    out:write(generate_script(out, config))

    return out:finish()
end

return M
