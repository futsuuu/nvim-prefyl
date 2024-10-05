local Path = require("prefyl.lib.Path")
local async = require("prefyl.lib.async")
local str = require("prefyl.lib.str")

local Chunk = require("prefyl.build.Chunk")
local Config = require("prefyl.build.Config")
local Out = require("prefyl.build.Out")
local Plugin = require("prefyl.build.Plugin")
local dump = require("prefyl.build.dump")
local installer = require("prefyl.build.installer")
local nvim = require("prefyl.build.nvim")
local runtime = require("prefyl.build.runtime")

local M = {}

---@param strip boolean
---@return prefyl.async.Future<prefyl.Path>
function M.build(strip)
    return async.async(function()
        local default_runtimepaths = nvim.default_runtimepaths()
        local config = Config.load(default_runtimepaths)

        installer.install(config)

        local out = Out.new(strip)

        local runtime_file = Path.prefyl_root / "lua" / "prefyl" / "runtime.lua"
        local s = str.dedent([[
        rawset(package.preload, "prefyl.runtime", loadstring(%q, %q))
        vim.api.nvim_set_var("did_load_ftdetect", 1)
        vim.api.nvim_set_option_value("loadplugins", false, {})
        vim.api.nvim_set_option_value("packpath", %q, {})
        ]]):format(
            dump(runtime_file, strip).await(),
            runtime_file:chunkname(),
            vim.iter(nvim.default_packpaths()):map(tostring):join(",")
        )

        s = s
            .. Plugin.new_std(config.std, default_runtimepaths)
                .await()
                :initialize(out)
                .await()
                :tostring()

        local scope = Chunk.scope()

        local plugins = {} ---@type table<string, prefyl.build.Plugin>
        for name, spec in pairs(config.plugins) do
            if not vim.list_contains(default_runtimepaths, spec.dir) then
                plugins[name] = Plugin.new(spec).await()
            end
        end

        for _, plugin in pairs(plugins) do
            scope:push(plugin:initialize(out).await())
        end

        for name, plugin in pairs(plugins) do
            if not plugin:is_lazy() then
                scope:push(runtime.load_plugin(name))
            end
        end

        s = s .. scope:to_chunk():tostring()

        out:write(s).await()
        return out:finish()
    end)
end

return M
