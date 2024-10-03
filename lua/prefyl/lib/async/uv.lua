local M = {}

local uv = require("luv")

local Future = require("prefyl.lib.async.Future")

---@generic A, B
---@param func fun(a: A, b: B)
---@return fun(b: B, a: A)
local function swap(func)
    return function(a, b)
        func(b, a)
    end
end

---@nodiscard
---@param path string
---@return prefyl.async.Future<uv.aliases.fs_stat_table?, string?>: stat?, err?
---@return uv_fs_t
function M.fs_stat(path)
    return Future.new(function(finish)
        return uv.fs_stat(path, swap(finish))
    end)
end

return M
