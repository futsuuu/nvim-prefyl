local test = require("prefyl.lib.test")

local M = {}

---@param str string
---@return string
function M.dedent(str)
    local lines = vim.iter(string.gmatch("\n" .. str, "\n([^\n]*)")):totable() ---@type string[]
    local size = vim.iter(lines)
        :filter(function(s) ---@param s string
            return s:find("%g") ~= nil
        end)
        :map(function(s) ---@param s string
            return select(2, s:find("^%s*"))
        end)
        :fold(math.huge, math.min)
    local indent_pat = "^" .. ("%s"):rep(size)
    return vim.iter(lines)
        :map(function(s) ---@param s string
            return (s:gsub(indent_pat, ""))
        end)
        :join("\n")
end

test.test("dedent", function()
    test.assert_eq(
        [[
hello

    world
        ]],
        M.dedent([[
            hello

                world
        ]])
    )
end)

---@param str string
---@param size integer
function M.indent(str, size)
    local indent = (" "):rep(size)
    return indent .. str:gsub("\n([^\n]+)", "\n" .. indent .. "%1")
end

test.test("indent", function()
    test.assert_eq(
        [[
        hello

            world
        ]],
        M.indent(
            [[
    hello

        world
    ]],
            4
        )
    )
end)

---@param str string
---@return string
function M.escape(str)
    str = str:gsub("%%", "%%%%")
    for _, s in ipairs({ "^", "$", "(", ")", ".", "[", "]", "*", "+", "-", "?" }) do
        str = str:gsub("%" .. s, "%%" .. s)
    end
    return str
end

test.test("escape", function()
    test.assert_eq("%[%]", M.escape("[]"))
    test.assert_eq("", ("[hel]lo* wo-rld?"):gsub(M.escape("[hel]lo* wo-rld?"), ""))
end)

---@param str string
---@param vars table<string, string|number>
---@return string
function M.format(str, vars)
    for w in str:gmatch("%%%a?{%g%g-}") do
        local seq, var = w:match("(%%%a?){(%g%g-)}") ---@type string, string
        local repl
        if seq == "%" then
            repl = vars[var]
        else
            repl = string.format(seq, vars[var])
        end
        str = str:gsub(M.escape(w), repl)
    end
    return str
end

test.test("format", function()
    test.assert_eq("Hello(world)!", M.format("%{msg}(%{name})!", { msg = "Hello", name = "world" }))
end)

return M
