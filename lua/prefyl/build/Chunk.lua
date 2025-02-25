local str = require("prefyl.lib.str")
local test = require("prefyl.lib.test")

---@class prefyl.build.Chunk
---@field package inner string
---@field package output string?
---@field package inputs prefyl.build.Chunk[]
---@field package fixed boolean
local M = {}
---@private
M.__index = M

---@param inputs prefyl.build.Chunk[]
---@return string[]
local function get_conflicted_outputs(inputs)
    local inputs_map = {} ---@type table<string, prefyl.build.Chunk>
    local conflicted_outputs = {} ---@type string[]
    for _, input in ipairs(inputs) do
        assert(input.output)
        if not inputs_map[input.output] then
            inputs_map[input.output] = input
        elseif not vim.deep_equal(inputs_map[input.output], input) then
            table.insert(conflicted_outputs, input.output)
        end
    end
    return conflicted_outputs
end

test.test("get_conflicted_outputs", function()
    test.assert_eq(
        { "b" },
        get_conflicted_outputs({
            M.new("local b = 2\n", { output = "b" }),
            M.new("local a = 1\n", { output = "a" }),
            M.new("local a = 1\n", { output = "a" }),
            M.new("local b = 1\n", { output = "b" }),
            M.new("local c = 1\n", { output = "c" }),
        })
    )
end)

---@param inputs prefyl.build.Chunk[]
---@return prefyl.build.Chunk[]
local function flatten_inputs(inputs)
    ---@type prefyl.build.Chunk[]
    local inputs = vim.iter(inputs)
        :map(function(input) ---@param input prefyl.build.Chunk
            input = vim.deepcopy(input)
            local inputs = input.inputs
            input.inputs = {}
            table.insert(inputs, input)
            return inputs
        end)
        :flatten()
        :totable()
    assert(#get_conflicted_outputs(inputs) == 0)
    return inputs
end

test.group("flatten_inputs", function()
    test.test("flatten", function()
        test.assert_eq(
            {
                M.new("local b = 1\n", { output = "b" }),
                M.new("local a = b\n", { output = "a" }),
                M.new("local c = 2\n", { output = "c" }),
            },
            flatten_inputs({
                M.new("local a = b\n", {
                    output = "a",
                    inputs = {
                        M.new("local b = 1\n", { output = "b" }),
                    },
                }),
                M.new("local c = 2\n", { output = "c" }),
            })
        )
    end)

    test.test("fail when conflicted", { fail = true }, function()
        flatten_inputs({
            M.new("local a = b\n", {
                output = "a",
                inputs = { M.new("local b = 1\n", { output = "b" }) },
            }),
            M.new("local c = b\n", {
                output = "c",
                inputs = { M.new("local b = 2\n", { output = "b" }) },
            }),
        })
    end)
end)

---@param default boolean?
---@param output string?
---@param inputs prefyl.build.Chunk[]
local function is_fixed(default, output, inputs)
    if
        vim.iter(inputs):any(function(input) ---@param input prefyl.build.Chunk
            return input.fixed
        end)
    then
        return true
    elseif default ~= nil then
        return default
    else
        return output == nil
    end
end

test.group("is_fixed", function()
    test.test("default ~= nil", function()
        test.assert_eq(false, is_fixed(false, "output", {}))
    end)

    test.test("output == nil", function()
        test.assert_eq(true, is_fixed(nil, nil, {}))
    end)

    test.test("fixed input", function()
        test.assert_eq(
            true,
            is_fixed(false, "output", {
                M.new("local b = 1", { output = "b" }),
                M.new("local a = 1", { output = "a", fixed = true }),
            })
        )
    end)
end)

---@param chunk string
---@param opts { output: string?, inputs: prefyl.build.Chunk[]?, fixed: boolean? }?
---@return prefyl.build.Chunk
function M.new(chunk, opts)
    opts = opts or {}
    local inputs = flatten_inputs(opts.inputs or {})
    local fixed = is_fixed(opts.fixed, opts.output, inputs)
    local self = setmetatable({}, M)
    self.inner = chunk
    self.inputs = inputs
    self.output = opts.output
    self.fixed = fixed
    return self
end

---@return string
function M:get_output()
    return assert(self.output)
end

---@param input prefyl.build.Chunk
---@param conflicted_outputs string[]?
---@return boolean
local function is_conficted_input(input, conflicted_outputs)
    return conflicted_outputs and vim.list_contains(conflicted_outputs, input.output) or false
end

---@param input prefyl.build.Chunk
---@param conflicted_outputs string[]?
---@return boolean
local function is_fixed_input(input, conflicted_outputs)
    return input.fixed or is_conficted_input(input, conflicted_outputs)
end

---@param chunk prefyl.build.Chunk
---@param root boolean
---@param conflicted_outputs string[]?
---@return string
local function tostr(chunk, root, conflicted_outputs)
    local s = vim.iter(chunk.inputs)
        :filter(function(input) ---@param input prefyl.build.Chunk
            return root or is_fixed_input(input, conflicted_outputs)
        end)
        :map(function(input) ---@param input prefyl.build.Chunk
            -- assert(#input.inputs == 0)
            return input.inner
        end)
        :join("") .. chunk.inner
    if
        vim.iter(chunk.inputs):any(function(input) ---@param input prefyl.build.Chunk
            return is_conficted_input(input, conflicted_outputs)
        end)
    then
        assert(not root)
        s = "do\n" .. str.indent(s, 4) .. "end\n"
    end
    return s
end

---@return string
function M:tostring()
    return tostr(self, true)
end
---@private
M.__tostring = M.tostring

---@param inputs prefyl.build.Chunk[]
---@param conflicted_outputs string[]?
---@return prefyl.build.Chunk[]
local function get_shared_inputs(inputs, conflicted_outputs)
    return vim.iter(inputs)
        :filter(function(input) ---@param input prefyl.build.Chunk
            return not is_fixed_input(input, conflicted_outputs)
        end)
        :fold({}, function(acc, input) ---@param input prefyl.build.Chunk
            local duplicated = vim.iter(acc):any(function(c) ---@param c prefyl.build.Chunk
                return input.output == c.output
            end)
            if not duplicated then
                table.insert(acc, input)
            end
            return acc
        end)
end

test.test("get_shared_inputs", function()
    test.assert_eq(
        {
            M.new("local a = 1\n", { output = "a" }),
            M.new("local c = 4\n", { output = "c" }),
        },
        get_shared_inputs({
            M.new("local a = 1\n", { output = "a" }),
            M.new("local c = 4\n", { output = "c" }),
            M.new("local b = 2\n", { output = "b", fixed = true }),
            M.new("local c = 4\n", { output = "c" }),
        })
    )
end)

---@param cond string
---@param body prefyl.build.Chunk
---@param opts { inputs: prefyl.build.Chunk[]? }?
---@return prefyl.build.Chunk
function M.if_(cond, body, opts)
    local opts = opts or {}
    return M.new(("if %s then\n"):format(cond) .. str.indent(tostr(body, false), 4) .. "end\n", {
        inputs = get_shared_inputs(
            vim.iter({ body.inputs, opts.inputs or {} }):flatten():totable()
        ),
    })
end

test.test("if", function()
    local foo = M.new('local foo = "bar"\n', { output = "foo" })
    test.assert_eq(
        M.new(
            str.dedent([[
            if foo == "bar" then
                local result = sleep(1000)
                print(foo, result)
            end
            ]]),
            { inputs = { foo } }
        ),
        M.if_(
            'foo == "bar"',
            M.new("print(foo, result)\n", {
                inputs = {
                    foo,
                    M.new("local result = sleep(1000)\n", { output = "result", fixed = true }),
                },
            }),
            { inputs = { foo } }
        )
    )
end)

---@nodiscard
---@param name string
---@param args string[]
---@param fn fun(args: table<string, prefyl.build.Chunk>): prefyl.build.Chunk
---@param opts { fixed: boolean? }?
---@return prefyl.build.Chunk
function M.function_(name, args, fn, opts)
    local opts = opts or {}
    ---@type table<string, prefyl.build.Chunk>
    local args_map = vim.iter(args):fold({}, function(acc, arg) ---@param arg string
        acc[arg] = M.new("", { output = arg, fixed = true })
        return acc
    end)
    local body = fn(args_map)
    return M.new(
        ("local %s = function(%s)\n"):format(name, table.concat(args, ", "))
            .. str.indent(tostr(body, false), 4)
            .. "end\n",
        { output = name, inputs = get_shared_inputs(body.inputs), fixed = opts.fixed }
    )
end

test.test("function", function()
    test.assert_eq(
        M.new(
            str.dedent([[
            local foo = function(a)
                local b = a + 1
                print(b, c)
            end
            ]]),
            {
                output = "foo",
                inputs = {
                    M.new("local c = 2\n", { output = "c" }),
                },
            }
        ),
        M.function_("foo", { "a" }, function(args)
            return M.new("print(b, c)\n", {
                inputs = {
                    M.new("local b = a + 1\n", { output = "b", inputs = { args.a } }),
                    M.new("local c = 2\n", { output = "c" }),
                },
            })
        end)
    )
end)

---@class prefyl.build.Chunk.Scope: { [integer]: prefyl.build.Chunk }
local Scope = {}
---@private
Scope.__index = Scope

---@param default prefyl.build.Chunk[]?
---@return prefyl.build.Chunk.Scope
function M.scope(default)
    if (getmetatable(default) or {}).__index == Scope then
        ---@cast default prefyl.build.Chunk.Scope
        return default
    end
    return setmetatable(default or {}, Scope)
end

---@param chunk prefyl.build.Chunk | string
---@return self
function Scope:push(chunk)
    if type(chunk) == "string" then
        chunk = M.new(chunk)
    end
    table.insert(self, chunk)
    return self
end

---@param pos integer
---@param chunk prefyl.build.Chunk | string
---@return self
function Scope:insert(pos, chunk)
    if type(chunk) == "string" then
        chunk = M.new(chunk)
    end
    table.insert(self, pos, chunk)
    return self
end

---@param chunks prefyl.build.Chunk[]
---@return self
function Scope:extend(chunks)
    vim.list_extend(self, chunks)
    return self
end

---@return prefyl.build.Chunk
function Scope:to_chunk()
    local inputs = vim.iter(self)
        :map(function(chunk)
            return chunk.inputs
        end)
        :flatten()
        :totable()
    local conflicted_outputs = get_conflicted_outputs(inputs)
    return M.new(
        vim.iter(self)
            :map(function(chunk) ---@param chunk prefyl.build.Chunk
                return tostr(chunk, false, conflicted_outputs)
            end)
            :join(""),
        { inputs = get_shared_inputs(inputs, conflicted_outputs) }
    )
end

test.group("Scope.to_chunk", function()
    test.test("different inputs", function()
        local a = M.new("local a = 1\n", { output = "a" })
        local b = M.new("local b = 1\n", { output = "b" })
        test.assert_eq(
            M.new(
                str.dedent([[
                print(a)
                print(b)
                ]]),
                { inputs = { a, b } }
            ),
            M.scope({
                M.new("print(a)\n", { inputs = { a } }),
                M.new("print(b)\n", { inputs = { b } }),
            }):to_chunk()
        )
    end)

    test.test("same inputs", function()
        local a = M.new("local a = 1\n", { output = "a" })
        test.assert_eq(
            M.new(
                str.dedent([[
                print(a)
                print(a)
                ]]),
                { inputs = { a } }
            ),
            M.scope({
                M.new("print(a)\n", { inputs = { a } }),
                M.new("print(a)\n", { inputs = { a } }),
            }):to_chunk()
        )
    end)

    test.test("fixed inputs", function()
        test.assert_eq(
            M.new(
                str.dedent([[
                local b = 2
                print(a, b)
                ]]),
                { inputs = { M.new("local a = 1\n", { output = "a" }) } }
            ),
            M.scope({
                M.new("print(a, b)\n", {
                    inputs = {
                        M.new("local a = 1\n", { output = "a" }),
                        M.new("local b = 2\n", { output = "b", fixed = true }),
                    },
                }),
            }):to_chunk()
        )
    end)

    test.test("conflicted inputs", function()
        test.assert_eq(
            M.new(str.dedent([[
            do
                local a = 1
                print(a)
            end
            print("hello")
            do
                local a = 2
                print(a)
            end
            ]])),
            M.scope({
                M.new("print(a)\n", { inputs = { M.new("local a = 1\n", { output = "a" }) } }),
                M.new('print("hello")\n'),
                M.new("print(a)\n", { inputs = { M.new("local a = 2\n", { output = "a" }) } }),
            }):to_chunk()
        )
    end)
end)

return M
