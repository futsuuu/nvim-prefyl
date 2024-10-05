local M = {}

local Future = require("prefyl.lib.async.Future")

---@return prefyl.async.Future<nil>
function M.schedule()
    return Future.new(vim.schedule)
end

return M
