local Path = require("prefyl.lib.path")
local test = require("prefyl.lib.test")

---@class prefyl.compiler.Config
---@field plugins table<string, prefyl.compiler.config.PluginSpec>

---@class prefyl.compiler.config.PluginSpec
---@field url string?
---@field dir prefyl.Path
---@field enabled boolean
---@field deps string[]
---@field lazy boolean
---@field cmd string[]
---@field event { event: string | string[], pattern: (string | string[])? }[]

local PLUGIN_ROOT = Path.stdpath.data / "prefyl" / "plugins"

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

---@return prefyl.compiler.Config
local function load()
    local config = require("prefyl.config")

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
            deps = spec.deps or {},
            enabled = spec.enabled ~= false,
            lazy = lazy,
            cmd = cmd,
            event = vim.iter(event):map(parse_event):totable(),
        }
    end

    return compiler_config
end

return load()
