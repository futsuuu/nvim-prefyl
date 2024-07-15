local Path = require("prefyl.lib.path")
local str = require("prefyl.lib.str")

local RuntimeDir = require("prefyl.compiler.rtdir")

local M = {}

---@type prefyl.Path[]
local DEFAULT_RUNTIMEPATHS = vim.iter({
    Path.prefyl_root,
    Path.stdpath.config,
    Path.stdpath.data / "site",
    Path.new(vim.env.VIMRUNTIME),
    Path.new(vim.env.VIM) / ".." / ".." / "lib" / "nvim",
    Path.stdpath.data / "site" / "after",
    Path.stdpath.config / "after",
})
    :filter(Path.exists)
    :totable()

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

vim.api.nvim_set_option_value("loadplugins", false, {})
vim.api.nvim_set_var("did_load_ftdetect", 1)

local plugin_loaders = {} ---@type table<string, function>
---@param plugin_name string?
local function load_plugin(plugin_name)
    local loader = rawget(plugin_loaders, plugin_name)
    if loader then
        rawset(plugin_loaders, plugin_name, nil)
        loader()
    end
end

]]

---@param name string
---@param body string
---@return string
local function setup_plugin_loader(name, body)
    return ("rawset(plugin_loaders, %q, function()\n"):format(name)
        .. str.indent(body, 4)
        .. "end)\n"
end

c = c
    .. [[
local luamodules = {} ---@type table<string, string>
local luamodule_owners = {} ---@type table<string, string>
---@param modname string
---@return string | function
local function luamodule_loader(modname)
    load_plugin(rawget(luamodule_owners, modname))
    local bytecode = rawget(luamodules, modname)
    if not bytecode then
        return "\n\tno cache '" .. modname .. "'"
    end
    local chunk, err = loadstring(bytecode, "b")
    return chunk or ("\n\t" .. err)
end
table.insert(package.loaders, 2, luamodule_loader)

]]
---@param plugin_name string
---@param module_name string
---@return string
local function register_luamodule(plugin_name, module_name)
    return ("rawset(luamodule_owners, %q, %q)\n"):format(module_name, plugin_name)
end
---@param module_name string
---@param bytecode string
---@return string
local function setup_luamodule(module_name, bytecode)
    return (("rawset(luamodules, %q, %q)\n"):format(module_name, bytecode):gsub("\\\n", "\\n"))
end

c = c
    .. [[
local colorscheme_owners = {} ---@type table<string, string>
vim.api.nvim_create_autocmd("ColorSchemePre", {
    callback = function(cx)
        load_plugin(rawget(colorscheme_owners, cx.match))
    end,
})

]]
---@param plugin_name string
---@param colorscheme string
---@return string
local function register_colorscheme(plugin_name, colorscheme)
    return ("rawset(colorscheme_owners, %q, %q)\n"):format(colorscheme, plugin_name)
end

c = c
    .. [[
---@param path string
local function source(path)
    vim.api.nvim_cmd({ cmd = "source", args = { path } }, {})
end

]]
---@param path prefyl.Path
---@return string
local function source(path)
    if path:exists() then
        return ("source(%q)\n"):format(path)
    else
        return ""
    end
end

c = c
    .. ('vim.api.nvim_set_option_value("runtimepath", %q, {})\n'):format(
        vim.iter(DEFAULT_RUNTIMEPATHS):map(tostring):join(",")
    )
    .. [[
---@param path string
local function prepend_to_rtp(path)
    local rtp = vim.api.nvim_get_option_value("runtimepath", {})
    vim.api.nvim_set_option_value("runtimepath", path .. "," .. rtp, {})
end
---@param path string
local function append_to_rtp(path)
    local rtp = vim.api.nvim_get_option_value("runtimepath", {})
    vim.api.nvim_set_option_value("runtimepath", rtp .. "," .. path, {})
end

]]
---@param path prefyl.Path
---@return string
local function add_to_rtp(path)
    if path:exists() then
        return path:ends_with("after") and ("append_to_rtp(%q)\n"):format(path)
            or ("prepend_to_rtp(%q)\n"):format(path)
    else
        return ("-- %q does not exist\n"):format(path)
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
        c = c .. vim.iter(rtdir.luamodules):map(setup_luamodule):join("")
    end
    for _, rtdir in ipairs(rtdirs) do
        c = c .. vim.iter(rtdir.init_files):map(source):join("")
    end
    return c
end

---@param deps string[]
---@return string
local function load_dependencies(deps)
    return vim.iter(deps)
        :map(function(s) ---@param s string
            return ("load_plugin(%q)\n"):format(s)
        end)
        :join("")
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
    local c = ""
    local interrupt_handlers = ""
    if spec.lazy then
        c = "local handler_interrupters = {} ---@type function[]\n"
        interrupt_handlers = str.dedent([[
        for _, fn in ipairs(handler_interrupters) do
            fn()
        end
        ]])
    end
    c = c
        .. setup_plugin_loader(
            name,
            interrupt_handlers
                .. load_dependencies(spec.deps)
                .. (spec_var .. ".config_pre()\n")
                .. load_rtdirs(rtdirs)
                .. (spec_var .. ".config()\n")
        )

    if spec.lazy then
        c = c
            .. str.dedent([[
            local function plugin_loader()
                load_plugin(%q)
            end
            ]]):format(name)
    end

    if spec.cmd then
        c = c .. 'local cmd = require("prefyl.handler.cmd")\n'
        for _, cmd in ipairs(spec.cmd) do
            c = c .. ("table.insert(handler_interrupters, cmd(plugin_loader, %q))\n"):format(cmd)
        end
    end

    c = c
        .. vim.iter(rtdirs)
            :map(function(rtdir) ---@param rtdir prefyl.compiler.RuntimeDir
                return vim.tbl_keys(rtdir.luamodules)
            end)
            :flatten()
            :fold("", function(acc, luamodule) ---@param luamodule string
                return acc .. register_luamodule(name, luamodule)
            end)
        .. vim.iter(rtdirs)
            :map(function(rtdir) ---@param rtdir prefyl.compiler.RuntimeDir
                return rtdir.colorschemes
            end)
            :flatten()
            :fold("", function(acc, colorscheme) ---@param colorscheme string
                return acc .. register_colorscheme(name, colorscheme)
            end)

    c = c .. (spec_var .. ".init()\n")
    return c
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

    c = c .. str.dedent([[
    local config = require("prefyl.config").load()

    ]])

    for name, spec in pairs(plugins) do
        if spec.enabled then
            c = c
                .. do_(
                    ("local spec = rawget(config.plugins, %q)\n"):format(name)
                        .. if_("spec.cond", initialize_plugin(name, spec, "spec"))
                )
        else
            c = c .. ("-- %q is disabled\n"):format(name)
        end
        c = c .. "\n"
    end

    c = c
        .. vim.iter(plugins)
            :filter(function(_name, spec) ---@param spec prefyl.compiler.config.PluginSpec
                return not spec.lazy
            end)
            :map(function(name, _spec)
                return ("load_plugin(%q)\n"):format(name)
            end)
            :join("")

    return c
end

---@return string
function M.compile()
    local config = require("prefyl.compiler.config").load()
    require("prefyl.compiler.installer").install(config)
    return compile(config)
end

return M
