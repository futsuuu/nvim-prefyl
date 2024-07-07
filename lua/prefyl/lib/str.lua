local test = require("prefyl.lib.test")

local M = {}

---@param str string
---@return string
function M.indoc(str)
    local info = debug.getinfo(2, "Sl")
    local file = assert(io.open(info.source:gsub("^@", ""), "r"))
    local called_line
    for _ = 1, info.currentline do
        called_line = assert(file:read("*l")) ---@type string
    end
    local indent = called_line:match("^(%s*)")
    return (str:gsub("^" .. indent, ""):gsub("\n" .. indent, "\n"))
end

test.test("indoc", function()
    test.assert_eq(
        [[
    hello
        world
]],
        M.indoc([[
            hello
                world
        ]])
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
