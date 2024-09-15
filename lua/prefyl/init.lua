local M = {}

---@param opts { load: boolean? }
function M.build(opts)
    local out = require("prefyl.build").build()
    if opts.load then
        dofile(out:tostring())
    end
end

return M
