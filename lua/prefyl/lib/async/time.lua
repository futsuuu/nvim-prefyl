local M = {}
package.loaded[...] = M

local uv = require("luv")

local Future = require("prefyl.lib.async.Future")

---@nodiscard
---@param ms uinteger
---@return prefyl.async.Future<nil>
function M.sleep(ms)
    local timer = assert(uv.new_timer())
    return Future.new(function(finish)
        timer:start(ms, 0, function()
            if not timer:is_closing() then
                timer:close()
            end
            finish()
        end)
    end)
end

return M
