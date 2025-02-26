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
        local default_runtimepaths = nvim.default_runtimepaths().await()
        local config = Config.load(default_runtimepaths)

        installer.install(config)

        local out = Out.new(strip).await()

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

        do
            local initializers = {} ---@type prefyl.build.Chunk[]
            local loaders = {} ---@type prefyl.build.Chunk[]
            local futures = {}
            for name, spec in pairs(config.plugins) do
                if not vim.list_contains(default_runtimepaths, spec.dir) then
                    local future = async.async(function()
                        local plugin = Plugin.new(spec).await()
                        table.insert(initializers, plugin:initialize(out).await())
                        if not plugin:is_lazy() then
                            table.insert(loaders, runtime.load_plugin(name))
                        end
                    end)
                    table.insert(futures, future)
                end
            end
            async.join_list(futures).await()
            scope:extend(initializers):extend(loaders)
        end

        s = s .. scope:to_chunk():tostring()

        out:write(s).await()
        return out:finish().await()
    end)
end

return M
