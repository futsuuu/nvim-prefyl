local M = {}
package.loaded[...] = M

local test = require("prefyl.lib.test")

local Future = require("prefyl.lib.async.Future")

M.Future = Future
M.time = require("prefyl.lib.async.time")
M.uv = require("prefyl.lib.async.uv")
M.vim = require("prefyl.lib.async.vim")

---@generic T, U, V, W, X, Y, Z
---@param func fun(): T?, U?, V?, W?, X?, Y?, Z?
---@return prefyl.async.Future<T?, U?, V?, W?, X?, Y?, Z?>
function M.async(func)
    return Future.new(function(finish)
        assert(coroutine.resume(coroutine.create(function()
            finish(func())
        end)))
    end)
end

---@generic T, U, V, W, X, Y, Z
---@param future prefyl.async.Future<T?, U?, V?, W?, X?, Y?, Z?>
---@return T?, U?, V?, W?, X?, Y?, Z?
function M.block_on(future)
    local finished = false
    M.async(function()
        future.await()
        finished = true
    end)
    vim.wait(2 ^ 20, function()
        return finished
    end)
    return future.await()
end

---@generic K, T
---@param futures table<K, prefyl.async.Future<T>>
---@return prefyl.async.Future<table<K, T>>
function M.join_all(futures)
    return Future.new(function(finish)
        local all = #vim.tbl_keys(futures)
        if all == 0 then
            finish({})
        end

        local finish = function()
            local result = {}
            if vim.islist(futures) then
                for _, future in ipairs(futures) do
                    table.insert(result, future.await())
                end
            else
                for key, future in pairs(futures) do
                    result[key] = future.await()
                end
            end
            finish(result)
        end

        local done = 0
        for _, future in pairs(futures) do
            M.async(function()
                future.await()
                done = done + 1
                if done == all then
                    finish()
                end
            end)
        end
    end)
end

test.group("join_all", function()
    test.test("empty", function()
        M.join_all({}).await()
    end)

    test.test("dict", function()
        test.assert_eq(
            { a = 1, c = 3 },
            M.block_on(M.join_all({
                a = M.async(function()
                    M.time.sleep(100).await()
                    return 1
                end),
                b = M.async(function()
                    M.time.sleep(200).await()
                    return nil
                end),
                c = M.async(function()
                    M.time.sleep(300).await()
                    return 3
                end),
            }))
        )
    end)

    test.test("list", function()
        test.assert_eq(
            { 1, 3 },
            M.join_all({
                M.async(function()
                    return 1
                end),
                M.async(function()
                    return nil
                end),
                M.async(function()
                    return 3
                end),
            }).await()
        )
    end)
end)

return M
