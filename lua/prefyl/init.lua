local M = {}

---@param opts? { debug?: boolean, run?: boolean }
function M.build(opts)
    opts = opts or {}
    local out = require("prefyl.build").build(not opts.debug)
    if opts.run then
        dofile(out:tostring())
    end
end

return M
