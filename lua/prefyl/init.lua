local M = {}

---@param opts { load: boolean? }
function M.compile(opts)
    local out = (require("prefyl.lib.path").stdpath.state / "prefyl" / "compiled.luac"):ensure_parent_dir()
    local script = require("prefyl.compiler").compile()
    local bytecode = string.dump(assert(loadstring(script)), true)
    do
        local f = assert(io.open(out:tostring(), "wb"))
        f:write(bytecode)
        f:close()
    end
    do
        local f = assert(io.open(out:set_ext("lua"):tostring(), "w"))
        f:write(script)
        f:close()
    end
    if opts.load == true then
        assert(loadstring(script))()
    end
end

return M
