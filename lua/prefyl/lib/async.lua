local M = {}
package.loaded[...] = M

local Future = require("prefyl.lib.async.Future")

M.Future = Future

---@nodiscard
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
    local wrapper = M.async(function()
        return (function(...)
            finished = true
            return ...
        end)(future.await())
    end)
    vim.wait(2 ^ 20, function()
        return finished
    end)
    return wrapper.await()
end

return M
