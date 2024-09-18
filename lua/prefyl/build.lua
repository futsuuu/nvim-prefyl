local Path = require("prefyl.lib.path")
local str = require("prefyl.lib.str")

local Chunk = require("prefyl.build.chunk")
local Config = require("prefyl.build.config")
local Out = require("prefyl.build.out")
local RuntimeDir = require("prefyl.build.rtdir")
local dump = require("prefyl.build.dump")
local installer = require("prefyl.build.installer")
local nvim = require("prefyl.build.nvim")
local runtime = require("prefyl.build.runtime")

local M = {}

local default_runtimepaths = nvim.default_runtimepaths()

---@param rtdirs prefyl.build.RuntimeDir[]
---@param after boolean
---@param disabled_plugins prefyl.Path[]
---@return prefyl.build.chunk.Scope
local function load_rtdirs(rtdirs, after, disabled_plugins)
    local scope = Chunk.scope()

    if not after then
        scope:push(nvim.add_to_rtp(vim.iter(rtdirs)
            :map(function(rtdir) ---@param rtdir prefyl.build.RuntimeDir
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
            vim.iter(rtdirs)
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

    return scope
end

---@param deps string[]
---@param after boolean
---@return prefyl.build.Chunk[]
local function load_dependencies(deps, after)
    if not after then
        return vim.iter(deps):map(runtime.load_plugin):totable()
    else
        return vim.iter(deps):rev():map(runtime.load_after_plugin):totable()
    end
end

---@param plugin_var prefyl.build.Chunk
---@param name string
---@return prefyl.build.Chunk
local function call_plugin_func(plugin_var, name)
    return Chunk.if_(
        ("%s.%s"):format(plugin_var:get_output(), name),
        Chunk.new(
            ("pcall(%s.%s)\n"):format(plugin_var:get_output(), name),
            { inputs = { plugin_var } }
        ),
        { inputs = { plugin_var } }
    )
end

---@param name string
---@param spec prefyl.build.config.PluginSpec
---@param plugin_var prefyl.build.Chunk
---@return prefyl.build.chunk.Scope
local function initialize_plugin(name, spec, plugin_var)
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
                :push(call_plugin_func(plugin_var, "config_pre"))
                :extend(load_rtdirs(rtdirs, false, spec.disabled_plugins))
                :to_chunk(),
            Chunk.scope()
                :extend(load_rtdirs(rtdirs, true, spec.disabled_plugins))
                :extend(load_dependencies(spec.deps.directly, true))
                :push(call_plugin_func(plugin_var, "config"))
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
            :map(function(rtdir) ---@param rtdir prefyl.build.RuntimeDir
                return rtdir.colorschemes
            end)
            :flatten()
            :totable()
        for _, colorscheme in ipairs(colorschemes) do
            scope:push(runtime.handle_colorscheme(name, colorscheme))
        end

        ---@type string[]
        local luamodules = vim.iter(rtdirs)
            :map(function(rtdir) ---@param rtdir prefyl.build.RuntimeDir
                return vim.tbl_keys(rtdir.luamodules)
            end)
            :flatten()
            :totable()
        for _, luamodule in ipairs(luamodules) do
            scope:push(runtime.handle_luamodule(name, luamodule))
        end
    end

    scope:push(call_plugin_func(plugin_var, "init"))

    return scope
end

---@param name string
---@param spec prefyl.build.config.PluginSpec
---@return prefyl.build.Chunk
local function initialize_plugin_if_needed(name, spec)
    local plugins = Chunk.new(
        'local plugins = require("prefyl.runtime.config").plugins\n',
        { output = "plugins" }
    )
    local plugin = Chunk.new(
        ("local plugin = plugins[%q] or {}\n"):format(name),
        { output = "plugin", inputs = { plugins } }
    )
    local cond = vim.iter(spec.deps.recursive)
        :flatten()
        :map(function(s)
            return ("(plugins[%q] or {})"):format(s)
        end)
        :fold("plugin.cond ~= false", function(acc, spec)
            return ("%s and %s.cond ~= false"):format(acc, spec)
        end)
    return Chunk.if_(
        cond,
        initialize_plugin(name, spec, plugin):to_chunk(),
        { inputs = { plugin, plugins } }
    )
end

---@param spec prefyl.build.config.PluginSpec
---@param plugins table<string, prefyl.build.config.PluginSpec>
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

---@param out prefyl.build.Out
---@param config prefyl.build.Config
---@return string
local function generate_script(out, config)
    local runtime_file = Path.prefyl_root / "lua" / "prefyl" / "runtime.lua"
    local s = str.dedent([[
    rawset(package.preload, "prefyl.runtime", loadstring(%q, %q))
    vim.api.nvim_set_var("did_load_ftdetect", 1)
    vim.api.nvim_set_option_value("loadplugins", false, {})
    vim.api.nvim_set_option_value("runtimepath", %q, {})
    ]]):format(
        dump(runtime_file, true),
        "@" .. runtime_file:tostring(),
        vim.iter(default_runtimepaths):map(tostring):join(",")
    )

    local default_rtdirs = vim.iter(default_runtimepaths):map(RuntimeDir.new):totable()
    s = s
        .. Chunk.scope()
            :extend(load_rtdirs(default_rtdirs, false, {}))
            :extend(load_rtdirs(default_rtdirs, true, {}))
            :to_chunk()
            :tostring()

    ---@type table<string, prefyl.build.config.PluginSpec>
    local plugins = vim.iter(config.plugins)
        :filter(function(_name, spec) ---@param spec prefyl.build.config.PluginSpec
            return not vim.list_contains(default_runtimepaths, spec.dir)
        end)
        :fold({}, function(acc, name, spec)
            acc[name] = spec
            return acc
        end)

    local scope = Chunk.scope()

    for name, spec in pairs(plugins) do
        if is_enabled(spec, plugins) then
            local initializer = initialize_plugin_if_needed(name, spec)
            if spec.lazy then
                scope:push(runtime.do_file(out:write(initializer:tostring())))
            else
                scope:push(initializer)
            end
        else
            scope:push(("-- %q is disabled\n"):format(name))
        end
    end

    scope:extend(vim.iter(plugins)
        :filter(function(_name, spec) ---@param spec prefyl.build.config.PluginSpec
            return not spec.lazy
        end)
        :map(function(name, _spec)
            return runtime.load_plugin(name)
        end)
        :totable())

    s = s .. scope:to_chunk():tostring()

    return s
end

---@param strip boolean
---@return prefyl.Path
function M.build(strip)
    local config = Config.load()
    local out = Out.new(strip)

    installer.install(config)
    out:write(generate_script(out, config))

    return out:finish()
end

return M
