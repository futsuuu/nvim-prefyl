---@class prefyl.async.Future<A, B, C, D, E, F, G>: { await: fun(): A, B, C, D, E, F, G }
local M = {}
package.loaded[...] = M

local async = require("prefyl.lib.async")

local list = require("prefyl.lib.list")
local test = require("prefyl.lib.test")

---@nodiscard
---@generic A, B, C, D, E, F, G, T, U, V, W, X, Y, Z
---@param executor fun(finish: fun(a: A?, b: B?, c: C?, d: D?, e: E?, f: F?, g: G?)): T?, U?, V?, W?, X?, Y?, Z?
---@return prefyl.async.Future<A?, B?, C?, D?, E?, F?, G?>
---@return T?, U?, V?, W?, X?, Y?, Z?
function M.new(executor)
    local co = nil ---@type thread?
    local result = nil ---@type table?

    local finished = false
    local function finish(...)
        if finished then
            return
        end
        finished = true
        if co then
            assert(coroutine.resume(co, ...))
        else
            result = list.pack(...)
        end
    end

    local function await()
        if not result then
            co = assert(coroutine.running(), "cannot yield from the main thread")
            result = list.pack(coroutine.yield())
        end
        return list.unpack(result)
    end

    return setmetatable({ await = await }, M), executor(finish)
end

test.group("new", function()
    test.test("finish immediately", function()
        local future, a, b = M.new(function(finish)
            finish(1, 2)
            return 3, 4
        end)
        test.assert_eq({ 3, 4 }, { a, b })
        test.assert_eq({ 1, 2 }, { future.await() })
    end)

    test.test("yield", { fail = true }, function()
        M.new(vim.schedule).await()
    end)

    test.test("resume", function()
        async.block_on(M.new(vim.schedule))
    end)
end)

---@param value any
---@return boolean
function M.is(value)
    return getmetatable(value) == M
end

test.test("is", function()
    assert(M.is(M.new(function() end)))
    assert(not M.is({}))
end)

return M
