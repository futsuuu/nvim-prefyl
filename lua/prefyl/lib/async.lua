local M = {}
package.loaded[...] = M

local Future = require("prefyl.lib.async.Future")

M.Future = Future
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
---@param callback fun(t: T?, u: U?, v: V?, w: W?, x: X?, y: Y?, z: Z?)
function M.add_callback(future, callback)
    M.async(function()
        return (function(...)
            callback(...)
            return ...
        end)(future.await())
    end)
end

---@generic T, U, V, W, X, Y, Z
---@param future prefyl.async.Future<T?, U?, V?, W?, X?, Y?, Z?>
---@return T?, U?, V?, W?, X?, Y?, Z?
function M.block_on(future)
    local finished = false
    M.add_callback(future, function()
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
        local finish = function()
            local result = {}
            for key, future in pairs(futures) do
                result[key] = future.await()
            end
            finish(result)
        end

        local all = #futures
        local done = 0

        for _, future in pairs(futures) do
            M.add_callback(future, function()
                done = done + 1
                if done == all then
                    finish()
                end
            end)
        end
    end)
end

return M
