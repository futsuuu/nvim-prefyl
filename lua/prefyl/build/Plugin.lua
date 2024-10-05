local async = require("prefyl.lib.async")

local Chunk = require("prefyl.build.Chunk")
local Config = require("prefyl.build.Config")
local RuntimeDir = require("prefyl.build.RuntimeDir")
local nvim = require("prefyl.build.nvim")
local runtime = require("prefyl.build.runtime")

---@class prefyl.build.Plugin
---@field private spec prefyl.build.Config.PluginSpec | prefyl.build.Config.StdSpec
---@field private rtdirs prefyl.build.RuntimeDir[]
local M = {}
---@private
M.__index = M

local rt_configs = Chunk.new('local plugins = require("prefyl.runtime.config").plugins\n', {
    output = "plugins",
})

---@param spec prefyl.build.Config.PluginSpec
---@return prefyl.async.Future<prefyl.build.Plugin>
function M.new(spec)
    return async.async(function()
        ---@type prefyl.build.Plugin
        local self = {
            spec = spec,
            rtdirs = {
                RuntimeDir.new(spec.dir).await(),
                RuntimeDir.new(spec.dir / "after").await(),
            },
        }
        return setmetatable(self, M)
    end)
end

---@param spec prefyl.build.Config.StdSpec
---@param paths prefyl.Path[]
---@return prefyl.async.Future<prefyl.build.Plugin>
function M.new_std(spec, paths)
    return async.async(function()
        ---@type prefyl.build.Plugin
        local self = {
            spec = spec,
            rtdirs = vim.iter(paths)
                :map(RuntimeDir.new)
                :map(function(future)
                    return (future.await())
                end)
                :totable(),
        }
        return setmetatable(self, M)
    end)
end

---@nodiscard
---@param out prefyl.build.Out
---@return prefyl.async.Future<prefyl.build.Chunk>
function M:initialize(out)
    local spec = self.spec

    return async.async(function()
        if not self:is_enabled() then
            ---@cast spec prefyl.build.Config.PluginSpec
            return Chunk.new(("-- %q is disabled\n"):format(spec.name))
        end

        local scope = Chunk.scope()

        local loader = Chunk.scope()
            :extend(self:load_dependencies(false))
            :push(self:set_rtp())
            :extend(self:set_luachunks())
            :push(self:call_rt_hook("config_pre"))
            :extend(self:load_rtdirs(false, self.spec.disabled_plugins))
        local after_loader = Chunk.scope()
            :extend(self:load_rtdirs(true, self.spec.disabled_plugins))
            :extend(self:load_dependencies(true))
            :push(self:call_rt_hook("config"))

        if self:is_std() then
            ---@cast spec prefyl.build.Config.StdSpec
            scope:extend(loader):extend(after_loader)
        else
            ---@cast spec prefyl.build.Config.PluginSpec
            if spec.lazy then
                local loader_file = out:write(loader:to_chunk():tostring()).await()
                local after_loader_file = out:write(after_loader:to_chunk():tostring()).await()
                scope
                    :push(runtime.prefetch_file(loader_file))
                    :push(runtime.prefetch_file(after_loader_file))
                    :push(
                        runtime.set_plugin_loader(
                            spec.name,
                            runtime.do_file_sync(loader_file),
                            runtime.do_file_sync(after_loader_file)
                        )
                    )
            else
                scope:push(
                    runtime.set_plugin_loader(spec.name, loader:to_chunk(), after_loader:to_chunk())
                )
            end
        end

        scope:extend(self:setup_lazy_handlers())

        scope:push(self:call_rt_hook("init"))

        if self:is_std() then
            return scope:to_chunk()
        end
        ---@cast spec prefyl.build.Config.PluginSpec

        local config = assert(self:rt_config())
        return Chunk.if_(
            vim.iter(spec.deps.recursive)
                :flatten()
                :map(function(s)
                    return ("(%s[%q] or {})"):format(rt_configs:get_output(), s)
                end)
                :fold(("%s.cond ~= false"):format(config:get_output()), function(acc, spec)
                    return ("%s and %s.cond ~= false"):format(acc, spec)
                end),
            scope:to_chunk(),
            { inputs = { rt_configs, config } }
        )
    end)
end

---@return boolean
function M:is_std()
    return (getmetatable(self.spec) or {}).__index == Config.StdSpec
end

---@return boolean
function M:is_enabled()
    local spec = self.spec
    if self:is_std() then
        return true
    end
    ---@cast spec prefyl.build.Config.PluginSpec
    if not spec.enabled then
        return false
    end
    for _, dep in ipairs(spec.deps.recursive) do
        if not spec.parent[dep].enabled then
            return false
        end
    end
    return true
end

---@return boolean
function M:is_lazy()
    local spec = self.spec
    if self:is_std() then
        return false
    end
    ---@cast spec prefyl.build.Config.PluginSpec
    return spec.lazy
end

---@nodiscard
---@param after boolean
---@param disabled_plugins prefyl.Path[]
---@return prefyl.build.Chunk.Scope
function M:load_rtdirs(after, disabled_plugins)
    return Chunk.scope()
        :extend(vim.iter(self.rtdirs)
            :filter(function(rtdir) ---@param rtdir prefyl.build.RuntimeDir
                return after == rtdir.dir:ends_with("after")
            end)
            :map(function(rtdir) ---@param rtdir prefyl.build.RuntimeDir
                return rtdir.plugin_files
            end)
            :flatten()
            :map(function(path) ---@param path prefyl.Path
                if not vim.list_contains(disabled_plugins, path) then
                    return nvim.source(path)
                else
                    return Chunk.new(("-- %q is disabled\n"):format(path))
                end
            end)
            :totable())
        :extend(nvim.augroup(
            "filetypedetect",
            vim.iter(self.rtdirs)
                :filter(function(rtdir) ---@param rtdir prefyl.build.RuntimeDir
                    return after == rtdir.dir:ends_with("after")
                end)
                :map(function(rtdir) ---@param rtdir prefyl.build.RuntimeDir
                    return rtdir.ftdetect_files
                end)
                :flatten()
                :map(nvim.source)
                :totable()
        ))
end

---@nodiscard
---@return prefyl.build.Chunk
function M:set_rtp()
    local paths = vim.iter(self.rtdirs)
        :map(function(rtdir) ---@param rtdir prefyl.build.RuntimeDir
            return rtdir.dir
        end)
        :totable()
    if self:is_std() then
        return nvim.set_rtp(paths)
    else
        return nvim.add_to_rtp(paths)
    end
end

---@nodiscard
---@return prefyl.build.Chunk.Scope
function M:set_luachunks()
    local scope = Chunk.scope()
    for _, rtdir in ipairs(self.rtdirs) do
        scope:extend(vim.iter(rtdir.luamodules):map(runtime.set_luachunk):totable())
    end
    return scope
end

---@nodiscard
---@return prefyl.build.Chunk.Scope
function M:setup_lazy_handlers()
    local scope = Chunk.scope()

    local spec = self.spec
    if self:is_std() then
        return scope
    end
    ---@cast spec prefyl.build.Config.PluginSpec

    if not spec.lazy then
        return scope
    end

    for _, cmd in ipairs(spec.cmd) do
        scope:push(runtime.handle_user_command(spec.name, cmd))
    end

    for _, event in ipairs(spec.event) do
        scope:push(runtime.handle_event(spec.name, event.event, event.pattern))
    end

    ---@type string[]
    local colorschemes = (not spec.colorscheme) and {}
        or vim.iter(self.rtdirs)
            :map(function(rtdir) ---@param rtdir prefyl.build.RuntimeDir
                return rtdir.colorschemes
            end)
            :flatten()
            :totable()
    for _, colorscheme in ipairs(colorschemes) do
        scope:push(runtime.handle_colorscheme(spec.name, colorscheme))
    end

    ---@type string[]
    local luamodules = (not spec.luamodule) and {}
        or vim.iter(self.rtdirs)
            :map(function(rtdir) ---@param rtdir prefyl.build.RuntimeDir
                return vim.tbl_keys(rtdir.luamodules)
            end)
            :flatten()
            :totable()
    for _, luamodule in ipairs(luamodules) do
        scope:push(runtime.handle_luamodule(spec.name, luamodule))
    end

    return scope
end

---@nodiscard
---@param after boolean
---@return prefyl.build.Chunk[]
function M:load_dependencies(after)
    local spec = self.spec
    if self:is_std() then
        return {}
    end
    ---@cast spec prefyl.build.Config.PluginSpec
    if not after then
        return vim.iter(spec.deps.directly):map(runtime.load_plugin):totable()
    else
        return vim.iter(spec.deps.directly):rev():map(runtime.load_after_plugin):totable()
    end
end

---@return prefyl.build.Chunk?
function M:rt_config()
    local spec = self.spec
    if self:is_std() then
        return
    end
    ---@cast spec prefyl.build.Config.PluginSpec
    return Chunk.new(
        ("local plugin = %s[%q] or {}\n"):format(rt_configs:get_output(), spec.name),
        { output = "plugin", inputs = { rt_configs } }
    )
end

---@nodiscard
---@param name string
function M:call_rt_hook(name)
    local config = self:rt_config()
    if not config then
        return Chunk.new("")
    end
    return Chunk.if_(
        ("%s.%s"):format(config:get_output(), name),
        Chunk.new(("pcall(%s.%s)\n"):format(config:get_output(), name), { inputs = { config } }),
        { inputs = { config } }
    )
end

return M
