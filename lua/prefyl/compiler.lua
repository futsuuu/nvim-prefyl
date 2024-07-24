local Path = require("prefyl.lib.path")
local str = require("prefyl.lib.str")

local RuntimeDir = require("prefyl.compiler.rtdir")
local dump = require("prefyl.compiler.dump")

local M = {}

---@return prefyl.Path[]
local function default_runtimepaths()
    local ps = {
        Path.new(vim.env.VIMRUNTIME),
        Path.new(vim.env.VIM) / ".." / ".." / "lib" / "nvim",
        Path.prefyl_root,
    }
    ---@param path prefyl.Path?
    local function push(path)
        if path then
            table.insert(ps, 1, path)
            table.insert(ps, path / "after")
        end
    end
    push(Path.stdpath.data_dirs[2] and (Path.stdpath.data_dirs[2] / "site"))
    push(Path.stdpath.data_dirs[1] and (Path.stdpath.data_dirs[1] / "site"))
    push(Path.stdpath.data / "site")
    push(Path.stdpath.config_dirs[2])
    push(Path.stdpath.config_dirs[1])
    push(Path.stdpath.config)
    return vim.iter(ps):filter(Path.exists):totable()
end

---@type prefyl.Path[]
local DEFAULT_RUNTIMEPATHS = default_runtimepaths()

---@param cond string
---@param body string
---@return string
local function if_(cond, body)
    if cond == "false" or cond == "nil" then
        return ""
    end
    return ("if %s then\n"):format(cond) .. str.indent(body, 4) .. "end\n"
end

---@param body string
---@return string
local function do_(body)
    return "do\n" .. str.indent(body, 4) .. "end\n"
end

local c = [[
-- vim:readonly:nowrap
---@diagnostic disable: unused-local, unused-function

]]

c = c
    .. ([[
vim.api.nvim_set_var("did_load_ftdetect", 1)
vim.api.nvim_set_option_value("loadplugins", false, {})
vim.api.nvim_set_option_value("runtimepath", %q, {})

]]):format(vim.iter(DEFAULT_RUNTIMEPATHS):map(tostring):join(","))

c = c
    .. ([[
rawset(package.preload, "prefyl.runtime", loadstring(%q))
local rt = require("prefyl.runtime")

]]):format(dump(Path.prefyl_root / "lua" / "prefyl" / "runtime.lua", true))

---@param plugin_name string
---@return string
local function load_plugin(plugin_name)
    return ("rt.load_plugin(%q)\n"):format(plugin_name)
end

---@param name string
---@param body string
---@return string
local function set_plugin_loader(name, body)
    return ("rt.set_plugin_loader(%q, function()\n"):format(name) .. str.indent(body, 4) .. "end)\n"
end

---@param module_name string
---@param chunk string
---@return string
local function set_luachunk(module_name, chunk)
    return ("rt.set_luachunk(%q, %q)\n"):format(module_name, chunk)
end

---@param plugin_name string
---@param module_name string
---@return string
local function handle_luamodule(plugin_name, module_name)
    if module_name == "prefyl.runtime" then
        return ""
    else
        return ("rt.handle_luamodule(%q, %q)\n"):format(plugin_name, module_name)
    end
end

---@param plugin_name string
---@param colorscheme string
local function handle_colorscheme(plugin_name, colorscheme)
    return ("rt.handle_colorscheme(%q, %q)\n"):format(plugin_name, colorscheme)
end

---@param plugin_name string
---@param user_command string
local function handle_user_command(plugin_name, user_command)
    return ("rt.handle_user_command(%q, %q)\n"):format(plugin_name, user_command)
end

---@param plugin_name string
---@param event string | string[]
---@param pattern (string | string[])?
local function handle_event(plugin_name, event, pattern)
    local args = ""
    args = args .. vim.inspect(event)
    if pattern then
        args = args .. ", " .. vim.inspect(pattern)
    end
    return ("rt.handle_event(%q, %s)\n"):format(plugin_name, args)
end

---@param path prefyl.Path
---@return string
local function source(path)
    if path:exists() then
        return ('vim.api.nvim_cmd({ cmd = "source", args = { %q } }, {})\n'):format(path)
    else
        return ""
    end
end

---@param group string
---@param body string
local function augroup(group, body)
    if body:find("%g") ~= nil then
        return str.dedent([[
        vim.api.nvim_cmd({ cmd = "augroup", args = { %q } }, {})
        %s
        vim.api.nvim_cmd({ cmd = "augroup", args = { "END" } }, {})
        ]]):format(group, body)
    else
        return ""
    end
end

---@param path prefyl.Path
---@return string
local function add_to_rtp(path)
    if not path:exists() then
        return ("-- %q does not exist\n"):format(path)
    end
    local get_rtp = 'vim.api.nvim_get_option_value("runtimepath", {})'
    if path:ends_with("after") then
        return ('vim.api.nvim_set_option_value("runtimepath", %s .. %q, {})\n'):format(
            get_rtp,
            "," .. path:tostring()
        )
    else
        return ('vim.api.nvim_set_option_value("runtimepath", %q .. %s, {})\n'):format(
            path:tostring() .. ",",
            get_rtp
        )
    end
end

---@param rtdirs prefyl.compiler.RuntimeDir[]
---@return string
local function load_rtdirs(rtdirs)
    local c = ""
    for _, rtdir in ipairs(rtdirs) do
        if not vim.list_contains(DEFAULT_RUNTIMEPATHS, rtdir.dir) then
            c = c .. add_to_rtp(rtdir.dir)
        end
        c = c .. vim.iter(rtdir.luamodules):map(set_luachunk):join("")
    end

    c = c
        .. vim.iter(rtdirs)
            :map(function(rtdir) ---@param rtdir prefyl.compiler.RuntimeDir
                return rtdir.plugin_files
            end)
            :flatten()
            :map(source)
            :join("")
        .. augroup(
            "filetypedetect",
            vim.iter(rtdirs)
                :map(function(rtdir) ---@param rtdir prefyl.compiler.RuntimeDir
                    return rtdir.ftdetect_files
                end)
                :flatten()
                :map(source)
                :join("")
        )

    return c
end

---@param deps string[]
---@return string
local function load_dependencies(deps)
    return vim.iter(deps):map(load_plugin):join("")
end

---@param name string
---@param spec prefyl.compiler.config.PluginSpec
---@param spec_var string
---@return string
local function initialize_plugin(name, spec, spec_var)
    local rtdirs = {
        RuntimeDir.new(spec.dir),
        RuntimeDir.new(spec.dir / "after"),
    }
    local c = set_plugin_loader(
        name,
        load_dependencies(spec.deps)
            .. if_(("%s.config_pre"):format(spec_var), ("pcall(%s.config_pre)\n"):format(spec_var))
            .. load_rtdirs(rtdirs)
            .. if_(("%s.config"):format(spec_var), ("pcall(%s.config)\n"):format(spec_var))
    )

    if spec.lazy then
        for _, cmd in ipairs(spec.cmd) do
            c = c .. handle_user_command(name, cmd)
        end

        for _, event in ipairs(spec.event) do
            c = c .. handle_event(name, event.event, event.pattern)
        end

        ---@type string[]
        local colorschemes = vim.iter(rtdirs)
            :map(function(rtdir) ---@param rtdir prefyl.compiler.RuntimeDir
                return rtdir.colorschemes
            end)
            :flatten()
            :totable()
        for _, colorscheme in ipairs(colorschemes) do
            c = c .. handle_colorscheme(name, colorscheme)
        end

        ---@type string[]
        local luamodules = vim.iter(rtdirs)
            :map(function(rtdir) ---@param rtdir prefyl.compiler.RuntimeDir
                return vim.tbl_keys(rtdir.luamodules)
            end)
            :flatten()
            :totable()
        for _, luamodule in ipairs(luamodules) do
            c = c .. handle_luamodule(name, luamodule)
        end
    end

    c = c .. if_(("%s.init"):format(spec_var), ("pcall(%s.init)\n"):format(spec_var))
    return c
end

---@param name string
---@param spec prefyl.compiler.config.PluginSpec
---@return string
local function initialize_plugin_if_needed(name, spec)
    if not spec.enabled then
        return ("-- %q is disabled\n"):format(name)
    end
    local c = str.dedent([[
    local spec = rawget(require("prefyl.config").plugins, %q)
    ]]):format(name)
    return do_(c .. if_("spec.cond ~= false", initialize_plugin(name, spec, "spec")))
end

---@param config prefyl.compiler.Config
---@return string
local function compile(config)
    local c = c

    c = c .. load_rtdirs(vim.iter(DEFAULT_RUNTIMEPATHS):map(RuntimeDir.new):totable()) .. "\n"

    ---@type table<string, prefyl.compiler.config.PluginSpec>
    local plugins = vim.iter(config.plugins)
        :filter(function(_name, spec) ---@param spec prefyl.compiler.config.PluginSpec
            return not vim.list_contains(DEFAULT_RUNTIMEPATHS, spec.dir)
        end)
        :fold({}, function(acc, name, spec)
            acc[name] = spec
            return acc
        end)

    c = c .. vim.iter(plugins):map(initialize_plugin_if_needed):join("\n") .. "\n"

    c = c
        .. vim.iter(plugins)
            :filter(function(_name, spec) ---@param spec prefyl.compiler.config.PluginSpec
                return not spec.lazy
            end)
            :map(function(name, _spec)
                return load_plugin(name)
            end)
            :join("")

    return (c:gsub("\\\n", "\\n"))
end

---@return string
function M.compile()
    local config = require("prefyl.compiler.config")
    require("prefyl.compiler.installer").install(config)
    return compile(config)
end

return M
