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
    local r = {}
    local skip = false
    for line in vim.gsplit(str, "\n") do
        if not skip and line ~= "" then
            line = indent .. line
        end
        table.insert(r, line)
        skip = line:sub(-1) == "\\"
    end
    return table.concat(r, "\n")
end

test.test("indent", function()
    local before = [[
    hello\
,

        world
    ]]
    local after = [[
        hello\
,

            world
        ]]
    test.assert_eq(after, M.indent(before, 4))
end)

return M
