local M = {}

---@param opts { load: boolean? }
function M.compile(opts)
    local out = require("prefyl.compiler").compile()
    if opts.load then
        dofile(out:tostring())
    end
end

return M
