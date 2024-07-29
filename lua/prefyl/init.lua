local M = {}

---@param opts { load: boolean? }
function M.compile(opts)
    local state_dir = (require("prefyl.lib.path").stdpath.state / "prefyl"):ensure_dir()

    local script = require("prefyl.compiler").compile()
    state_dir:join("compiled.lua"):write(script, assert)

    local bytecode = string.dump(assert(loadstring(script)), true)
    state_dir:join("compiled.luac"):write(bytecode, assert)

    if opts.load then
        assert(loadstring(script))()
    end
end

return M
