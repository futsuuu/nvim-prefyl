local M = {}

local Future = require("prefyl.lib.async.Future")

---@nodiscard
---@return prefyl.async.Future<nil>
function M.schedule()
    return Future.new(vim.schedule)
end

function M.ensure_scheduled()
    if vim.in_fast_event() then
        M.schedule().await()
    end
end

return M
