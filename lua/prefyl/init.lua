local M = {}

---@param opts? { debug?: boolean, run?: boolean }
function M.build(opts)
    local async = require("prefyl.lib.async")
    local result = require("prefyl.lib.result")

    local build = require("prefyl.build")

    opts = opts or {}

    ---@type prefyl.async.Future<prefyl.Result<prefyl.Path, any>>
    local out = async.async(function()
        return result.map_err(build.build(not opts.debug).await(), function(err)
            async.vim.ensure_scheduled()
            vim.notify(tostring(err), vim.log.levels.ERROR)
            return err
        end)
    end)

    if opts.run then
        async.block_on(async.async(function()
            result.map(out.await(), function(path)
                async.vim.ensure_scheduled()
                dofile(path:tostring())
                return path
            end)
        end))
    end
end

return M
