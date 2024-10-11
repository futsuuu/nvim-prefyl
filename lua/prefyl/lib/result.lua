local M = {}

local list = require("prefyl.lib.list")
local test = require("prefyl.lib.test")

---@class prefyl.Result<T, E>: { val: T?, err: E?, ensure: fun(): T }

local METADATA_KEY = newproxy(false)

---@class prefyl.Result.Metadata
---@field success boolean

---@param lhs prefyl.Result<any, any>
---@param rhs prefyl.Result<any, any>
local function equal(lhs, rhs)
    return M.is(lhs)
        and M.is(rhs)
        and lhs.val == rhs.val
        and lhs.err == rhs.err
        and M.is_ok(lhs) == M.is_ok(rhs)
end

---@param success boolean
---@param val any
---@param err any
---@return prefyl.Result<any, any>
local function new(success, val, err)
    local result = {}
    return setmetatable(result, {
        ---@type prefyl.Result<any, any>
        __index = {
            val = val,
            err = err,
            ensure = function()
                if success then
                    return val
                else
                    error(result)
                end
            end,
            ---@type prefyl.Result.Metadata
            [METADATA_KEY] = {
                success = success,
            },
        },
        __eq = equal,
        __newindex = function()
            error("'prefyl.Result' is immutable")
        end,
    })
end

---@generic F: function
---@param func F
---@return F
function M.wrap(func)
    return function(...)
        local result = list.pack(pcall(func, ...))
        if M.is(result[2]) then
            return list.unpack(result, 2)
        elseif not result[1] then
            error(result[2])
        end
        local i = debug.getinfo(func, "Sl")
        error(
            ("function defined in %s:%s returns %s ('prefyl.Result' expected)"):format(
                i.short_src,
                i.linedefined,
                result[2]
            )
        )
    end
end

test.test("ensure", function()
    local result = M.wrap(function()
        test.assert_eq(1, M.ok(1).ensure())
        M.err(2).ensure()
        return M.ok(3)
    end)()
    test.assert_eq(M.err(2), result)
end)

---@generic T
---@param success boolean
---@param val T
---@return prefyl.Result<T, unknown>
function M.from_bool(success, val)
    return new(success, val, val)
end

---@generic T, E
---@param val T?
---@param err E?
---@return prefyl.Result<T, E>
function M.from_opt(val, err)
    return new(not not val, val, err)
end

---@generic T
---@param val T
---@return prefyl.Result<T, nil>
function M.ok(val)
    return new(true, val, nil)
end

---@generic E
---@param err E
---@return prefyl.Result<nil, E>
function M.err(err)
    return new(false, nil, err)
end

---@generic T, U, E
---@param result prefyl.Result<T, E>
---@param f fun(val: T): U
---@return prefyl.Result<U, E>
function M.map(result, f)
    return M.is_ok(result) and new(true, f(result.val), nil) or result
end

---@generic T, E, F
---@param result prefyl.Result<T, E>
---@param f fun(err: E): F
---@return prefyl.Result<T, F>
function M.map_err(result, f)
    return M.is_err(result) and new(false, nil, f(result.err)) or result
end

---@param val any
---@return boolean
function M.is(val)
    return val[METADATA_KEY] ~= nil
end

---@param result prefyl.Result<any, any>
---@return self
local function metadata(result)
    return assert(result[METADATA_KEY], "prefyl.Result expected, got " .. vim.inspect(result))
end

---@param result prefyl.Result<any, any>
---@return boolean
function M.is_ok(result)
    return metadata(result).success
end

---@param result prefyl.Result<any, any>
---@return boolean
function M.is_err(result)
    return not metadata(result).success
end

return M
