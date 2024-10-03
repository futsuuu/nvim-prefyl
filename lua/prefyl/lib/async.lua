local M = {}
package.loaded[...] = M

local list = require("prefyl.lib.list")

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
---@param func fun(): T?, U?, V?, W?, X?, Y?, Z?
---@return T?, U?, V?, W?, X?, Y?, Z?
function M.block_on(func)
    local result = nil
    local _ = M.async(function()
        result = list.pack(func())
    end)
    vim.wait(2 ^ 20, function()
        return result ~= nil
    end)
    ---@cast result -nil
    return list.unpack(result)
end

return M
