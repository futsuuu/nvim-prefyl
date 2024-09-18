local Path = require("prefyl.lib.path")
local test = require("prefyl.lib.test")

---@class prefyl.build.Config
---@field plugins table<string, prefyl.build.config.PluginSpec>
local M = {}
---@private
M.__index = M

---@class prefyl.build.config.PluginSpec
---@field url string?
---@field dir prefyl.Path
---@field enabled boolean
---@field deps prefyl.build.config.Deps
---@field lazy boolean
---@field cmd string[]
---@field event prefyl.build.config.Event[]
---@field disabled_plugins prefyl.Path[]

---@class prefyl.build.config.Event
---@field event string | string[]
---@field pattern? string | string[]

---@class prefyl.build.config.Deps
---@field directly string[]
---@field recursive string[]

---@class prefyl._build
---@field plugins? table<string, prefyl._build.Plugin>

---@class prefyl._build.Plugin
---@field url string?
---@field dir string?
---@field enabled boolean?
---@field deps string[]?
---@field lazy boolean?
---@field cmd string[]?
---@field event string[]?
---@field disabled_plugins string[]?

local PLUGIN_ROOT = Path.stdpath.data / "prefyl" / "plugins"

---@generic T
---@param list T[]
---@return T[]
local function uniq(list)
    local map = {}
    local r = {}
    for _, v in ipairs(list) do
        if v ~= nil and not map[v] then
            map[v] = true
            table.insert(r, v)
        end
    end
    return r
end

test.test("uniq", function()
    test.assert_eq({ 1, 2, 3 }, uniq({ 1, 1, 2, 3, 1, 2, 3 }))
end)

---@param map table<string, string[]>
---@return table<string, prefyl.build.config.Deps>
local function recurse_deps(map)
    ---@type table<string, prefyl.build.config.Deps>
    local r = {}
    for name, deps in pairs(map) do
        deps = uniq(deps)
        r[name] = { directly = deps, recursive = vim.deepcopy(deps) }
    end

    repeat
        local changed = false

        for _, deps in pairs(r) do
            local deps_deps = vim.iter(deps.recursive)
                :map(function(dep) ---@param dep string
                    return r[dep].recursive
                end)
                :flatten()
                :totable()

            local len = #deps.recursive
            vim.list_extend(deps.recursive, deps_deps)
            deps.recursive = uniq(deps.recursive)
            if len ~= #deps.recursive then
                changed = true
            end
        end
    until not changed

    return r
end

test.group("recurse_deps", function()
    test.test("recurse", function()
        test.assert_eq(
            {
                z = { directly = { "a" }, recursive = { "a", "b", "c", "d" } },
                a = { directly = { "b" }, recursive = { "b", "c", "d" } },
                b = { directly = { "c" }, recursive = { "c", "d" } },
                c = { directly = { "d" }, recursive = { "d" } },
                d = { directly = {}, recursive = {} },
            },
            recurse_deps({
                z = { "a" },
                a = { "b" },
                b = { "c" },
                c = { "d" },
                d = {},
            })
        )
    end)

    test.test("cycle", function()
        test.assert_eq(
            {
                a = { directly = { "b" }, recursive = { "b", "c", "a" } },
                b = { directly = { "c" }, recursive = { "c", "a", "b" } },
                c = { directly = { "a" }, recursive = { "a", "b", "c" } },
            },
            recurse_deps({
                a = { "b" },
                b = { "c" },
                c = { "a" },
            })
        )
    end)
end)

---@param event string
---@return prefyl.build.config.Event
local function parse_event(event)
    ---@type string, string?
    local event, pattern = unpack(vim.split(event, " "))
    local event = event:find(",") and vim.split(event, ",") or event
    if type(event) == "table" and #event == 1 then
        event = event[1]
    end
    local pattern = pattern and pattern:find(",") and vim.split(pattern, ",") or pattern
    if type(pattern) == "table" and #pattern == 1 then
        pattern = pattern[1]
    end
    return { event = event, pattern = pattern }
end

test.group("parse_event", function()
    test.test("event only", function()
        test.assert_eq({ event = "InsertEnter" }, parse_event("InsertEnter"))
        test.assert_eq({ event = { "InsertEnter", "BufRead" } }, parse_event("InsertEnter,BufRead"))
    end)

    test.test("event and pattern", function()
        test.assert_eq(
            { event = "BufRead", pattern = "Cargo.toml" },
            parse_event("BufRead Cargo.toml")
        )
        test.assert_eq(
            { event = { "BufRead", "BufNewFile" }, pattern = { "*.txt", "*.md" } },
            parse_event("BufRead,BufNewFile *.txt,*.md")
        )
    end)
end)

---@param dir prefyl.Path
---@param ss string[]
---@return prefyl.Path[]
local function expand_disabled_plugins(dir, ss)
    return vim.iter(ss)
        :map(function(name) ---@param name string
            return { dir / "plugin" / name, dir / "after" / "plugin" / name }
        end)
        :flatten()
        :map(function(path) ---@param path prefyl.Path
            local ext = path:ext()
            if ext == "lua" or ext == "vim" then
                return { path }
            else
                return { path:set_ext("lua"), path:set_ext("vim") }
            end
        end)
        :flatten()
        :totable()
end

test.test("expand_disabled_plugins", function()
    test.assert_eq({
        Path.new("plugin/hello.lua"),
        Path.new("plugin/hello.vim"),
        Path.new("after/plugin/hello.lua"),
        Path.new("after/plugin/hello.vim"),
        Path.new("plugin/world.vim"),
        Path.new("after/plugin/world.vim"),
    }, expand_disabled_plugins(Path.new(""), { "hello", "world.vim" }))
end)

---@return prefyl.build.Config
function M.load()
    ---@type boolean, prefyl._build?
    local _, config = pcall(require, "prefyl._build")
    if not config then
        ---@type prefyl.build.Config
        local build_config = {
            plugins = {},
        }
        return setmetatable(build_config, M)
    end

    ---@type table<string, string[]>
    local deps_map = vim.iter(config.plugins or {})
        :fold({}, function(acc, name, plugin) ---@param plugin prefyl._build.Plugin
            acc[name] = plugin.deps or {}
            return acc
        end)
    local deps_map = recurse_deps(deps_map)

    ---@type prefyl.build.Config
    local build_config = {
        plugins = {},
    }
    for name, plugin in pairs(config.plugins) do
        local cmd = plugin.cmd or {}
        local event = plugin.event or {}
        local lazy = plugin.lazy
        if lazy == nil then
            lazy = 0 < #cmd or 0 < #event
        end
        local dir = plugin.dir and Path.new(plugin.dir) or (PLUGIN_ROOT / name)
        ---@type prefyl.build.config.PluginSpec
        local spec = {
            dir = dir,
            url = plugin.url,
            deps = deps_map[name],
            enabled = plugin.enabled ~= false,
            lazy = lazy,
            cmd = cmd,
            event = vim.iter(event):map(parse_event):totable(),
            disabled_plugins = expand_disabled_plugins(dir, plugin.disabled_plugins or {}),
        }
        build_config.plugins[name] = spec
    end

    return setmetatable(build_config, M)
end

return M
