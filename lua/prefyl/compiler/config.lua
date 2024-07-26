local Path = require("prefyl.lib.path")
local test = require("prefyl.lib.test")

---@class prefyl.compiler.Config
---@field plugins table<string, prefyl.compiler.config.PluginSpec>

---@class prefyl.compiler.config.PluginSpec
---@field url string?
---@field dir prefyl.Path
---@field enabled boolean
---@field deps prefyl.compiler.config.Deps
---@field lazy boolean
---@field cmd string[]
---@field event { event: string | string[], pattern: (string | string[])? }[]

---@class prefyl.compiler.config.Deps
---@field directly string[]
---@field recursive string[]

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
---@return table<string, prefyl.compiler.config.Deps>
local function recurse_deps(map)
    ---@type table<string, prefyl.compiler.config.Deps>
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
---@return { event: string | string[], pattern: (string | string[])? }
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

---@param config prefyl.Config
---@return prefyl.Config
local function validate(config)
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

    return config
end

---@return prefyl.compiler.Config
local function load()
    local config = validate(require("prefyl.config"))

    ---@type table<string, string[]>
    local deps_map = vim.iter(config.plugins or {})
        :fold({}, function(acc, name, spec) ---@param spec prefyl.config.PluginSpec
            acc[name] = spec.deps or {}
            return acc
        end)
    local deps_map = recurse_deps(deps_map)

    ---@type prefyl.compiler.Config
    local compiler_config = {
        plugins = {},
    }
    for name, spec in pairs(config.plugins) do
        local cmd = spec.cmd or {}
        local event = spec.event or {}
        local lazy = spec.lazy
        if lazy == nil then
            lazy = 0 < #cmd or 0 < #event
        end
        ---@type prefyl.compiler.config.PluginSpec
        compiler_config.plugins[name] = {
            dir = spec.dir and Path.new(spec.dir) or (PLUGIN_ROOT / name),
            url = spec.url,
            deps = deps_map[name],
            enabled = spec.enabled ~= false,
            lazy = lazy,
            cmd = cmd,
            event = vim.iter(event):map(parse_event):totable(),
        }
    end

    return compiler_config
end

return load()
