---@class prefyl.async.Future<A, B, C, D, E, F, G>: { await: fun(): A, B, C, D, E, F, G }
local M = {}
package.loaded[...] = M

local list = require("prefyl.lib.list")
local test = require("prefyl.lib.test")

---@nodiscard
---@generic A, B, C, D, E, F, G, T, U, V, W, X, Y, Z
---@param executor fun(finish: fun(a: A?, b: B?, c: C?, d: D?, e: E?, f: F?, g: G?)): T?, U?, V?, W?, X?, Y?, Z?
---@return prefyl.async.Future<A?, B?, C?, D?, E?, F?, G?>
---@return T?, U?, V?, W?, X?, Y?, Z?
function M.new(executor)
    local threads = {} ---@type thread[]
    local result = nil ---@type table?

    local finished = false
    local function finish(...)
        if finished then
            return
        end
        finished = true
        if threads[1] == nil then
            result = list.pack(...)
        else
            for _, co in ipairs(threads) do
                assert(coroutine.resume(co, ...))
            end
        end
    end

    local function await()
        if not result then
            local co = assert(coroutine.running(), "cannot yield from the main thread")
            table.insert(threads, co)
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

    test.test("multiple await", function()
        local future = M.new(vim.schedule)
        local a = 0
        for _ = 1, 1000 do
            assert(coroutine.resume(coroutine.create(function()
                future.await()
                a = a + 1
            end)))
        end
        test.assert_eq(0, a)
        vim.wait(100)
        test.assert_eq(1000, a)
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
