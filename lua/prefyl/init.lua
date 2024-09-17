local M = {}

---@param opts { debug: boolean?, load: boolean? }
function M.build(opts)
    local out = require("prefyl.build").build(not opts.debug)
    if opts.load then
        dofile(out:tostring())
    end
end

return M
