local Path = require("prefyl.lib.path")
local str = require("prefyl.lib.str")

local Chunk = require("prefyl.compiler.chunk")
local RuntimeDir = require("prefyl.compiler.rtdir")
local dump = require("prefyl.compiler.dump")
local nvim = require("prefyl.compiler.nvim")
local runtime = require("prefyl.compiler.runtime")

local M = {}

local default_runtimepaths = nvim.default_runtimepaths()

---@param rtdirs prefyl.compiler.RuntimeDir[]
---@param after boolean
---@return prefyl.compiler.chunk.Scope
local function load_rtdirs(rtdirs, after)
    local scope = Chunk.scope()

    if not after then
        scope:push(nvim.add_to_rtp(vim.iter(rtdirs)
            :map(function(rtdir) ---@param rtdir prefyl.compiler.RuntimeDir
                return rtdir.dir
            end)
            :filter(function(path) ---@param path prefyl.Path
                return not vim.list_contains(default_runtimepaths, path) and path:exists()
            end)
            :totable()))
        for _, rtdir in ipairs(rtdirs) do
            scope:extend(vim.iter(rtdir.luamodules):map(runtime.set_luachunk):totable())
        end
    end

    scope
        :extend(vim.iter(rtdirs)
            :filter(function(rtdir) ---@param rtdir prefyl.compiler.RuntimeDir
                return after == rtdir.dir:ends_with("after")
            end)
            :map(function(rtdir) ---@param rtdir prefyl.compiler.RuntimeDir
                return rtdir.plugin_files
            end)
            :flatten()
            :map(nvim.source)
            :totable())
        :extend(nvim.augroup(
            "filetypedetect",
            vim.iter(rtdirs)
                :filter(function(rtdir) ---@param rtdir prefyl.compiler.RuntimeDir
                    return after == rtdir.dir:ends_with("after")
                end)
                :map(function(rtdir) ---@param rtdir prefyl.compiler.RuntimeDir
                    return rtdir.ftdetect_files
                end)
                :flatten()
                :map(nvim.source)
                :totable()
        ))

    return scope
end

---@param deps string[]
---@param after boolean
---@return prefyl.compiler.Chunk[]
local function load_dependencies(deps, after)
    if not after then
        return vim.iter(deps):map(runtime.load_plugin):totable()
    else
        return vim.iter(deps):rev():map(runtime.load_after_plugin):totable()
    end
end

---@param spec_var prefyl.compiler.Chunk
---@param name string
---@return prefyl.compiler.Chunk
local function call_spec_func(spec_var, name)
    return Chunk.if_(
        ("%s.%s"):format(spec_var:get_output(), name),
        Chunk.new(("pcall(%s.%s)\n"):format(spec_var:get_output(), name), { inputs = { spec_var } }),
        { inputs = { spec_var } }
    )
end

---@param name string
---@param spec prefyl.compiler.config.PluginSpec
---@param spec_var prefyl.compiler.Chunk
---@return prefyl.compiler.chunk.Scope
local function initialize_plugin(name, spec, spec_var)
    local rtdirs = {
        RuntimeDir.new(spec.dir),
        RuntimeDir.new(spec.dir / "after"),
    }
    local scope = Chunk.scope()
    scope:push(
        runtime.set_plugin_loader(
            name,
            Chunk.scope()
                :extend(load_dependencies(spec.deps.directly, false))
                :push(call_spec_func(spec_var, "config_pre"))
                :extend(load_rtdirs(rtdirs, false))
                :to_chunk(),
            Chunk.scope()
                :extend(load_rtdirs(rtdirs, true))
                :extend(load_dependencies(spec.deps.directly, true))
                :push(call_spec_func(spec_var, "config"))
                :to_chunk()
        )
    )

    if spec.lazy then
        for _, cmd in ipairs(spec.cmd) do
            scope:push(runtime.handle_user_command(name, cmd))
        end

        for _, event in ipairs(spec.event) do
            scope:push(runtime.handle_event(name, event.event, event.pattern))
        end

        ---@type string[]
        local colorschemes = vim.iter(rtdirs)
            :map(function(rtdir) ---@param rtdir prefyl.compiler.RuntimeDir
                return rtdir.colorschemes
            end)
            :flatten()
            :totable()
        for _, colorscheme in ipairs(colorschemes) do
            scope:push(runtime.handle_colorscheme(name, colorscheme))
        end

        ---@type string[]
        local luamodules = vim.iter(rtdirs)
            :map(function(rtdir) ---@param rtdir prefyl.compiler.RuntimeDir
                return vim.tbl_keys(rtdir.luamodules)
            end)
            :flatten()
            :totable()
        for _, luamodule in ipairs(luamodules) do
            scope:push(runtime.handle_luamodule(name, luamodule))
        end
    end

    scope:push(call_spec_func(spec_var, "init"))

    return scope
end

---@param name string
---@param spec prefyl.compiler.config.PluginSpec
---@return prefyl.compiler.Chunk
local function initialize_plugin_if_needed(name, spec)
    local plugins_var =
        Chunk.new('local plugins = require("prefyl.config").plugins\n', { output = "plugins" })
    local spec_var = Chunk.new(
        ("local spec = rawget(plugins, %q)\n"):format(name),
        { output = "spec", inputs = { plugins_var } }
    )
    local cond = vim.iter(spec.deps.recursive)
        :flatten()
        :map(function(s)
            return ("rawget(plugins, %q)"):format(s)
        end)
        :fold("spec.cond ~= false", function(acc, spec)
            return ("%s and %s.cond ~= false"):format(acc, spec)
        end)
    return Chunk.if_(
        cond,
        initialize_plugin(name, spec, spec_var):to_chunk(),
        { inputs = { spec_var, plugins_var } }
    )
end

---@param spec prefyl.compiler.config.PluginSpec
---@param plugins table<string, prefyl.compiler.config.PluginSpec>
---@return boolean
local function is_enabled(spec, plugins)
    if not spec.enabled then
        return false
    end
    for _, dep in ipairs(spec.deps.recursive) do
        if not plugins[dep].enabled then
            return false
        end
    end
    return true
end

---@param config prefyl.compiler.Config
---@return string
local function compile(config)
    local scope = Chunk.scope()

    local default_rtdirs = vim.iter(default_runtimepaths):map(RuntimeDir.new):totable()
    scope:extend(load_rtdirs(default_rtdirs, false)):extend(load_rtdirs(default_rtdirs, true))

    ---@type table<string, prefyl.compiler.config.PluginSpec>
    local plugins = vim.iter(config.plugins)
        :filter(function(_name, spec) ---@param spec prefyl.compiler.config.PluginSpec
            return not vim.list_contains(default_runtimepaths, spec.dir)
        end)
        :fold({}, function(acc, name, spec)
            acc[name] = spec
            return acc
        end)

    for name, spec in pairs(plugins) do
        if is_enabled(spec, plugins) then
            scope:push(initialize_plugin_if_needed(name, spec))
        else
            scope:push(("-- %q is disabled\n"):format(name))
        end
    end

    scope:extend(vim.iter(plugins)
        :filter(function(_name, spec) ---@param spec prefyl.compiler.config.PluginSpec
            return not spec.lazy
        end)
        :map(function(name, _spec)
            return runtime.load_plugin(name)
        end)
        :totable())

    local s = str.dedent([[
    -- vim:readonly:nowrap
    rawset(package.preload, "prefyl.runtime", loadstring(%q))
    vim.api.nvim_set_var("did_load_ftdetect", 1)
    vim.api.nvim_set_option_value("loadplugins", false, {})
    vim.api.nvim_set_option_value("runtimepath", %q, {})
    ]]):format(
        dump(Path.prefyl_root / "lua" / "prefyl" / "runtime.lua", true),
        vim.iter(default_runtimepaths):map(tostring):join(",")
    ) .. scope:to_chunk():tostring()

    return (s:gsub("\\\n", "\\n"))
end

---@return string
function M.compile()
    local config = require("prefyl.compiler.config")
    require("prefyl.compiler.installer").install(config)
    return compile(config)
end

return M
