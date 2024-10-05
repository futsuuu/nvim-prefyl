local Path = require("prefyl.lib.Path")
local async = require("prefyl.lib.async")

local LUAC_DIR = Path.stdpath.cache / "prefyl" / "luac"

---@param path prefyl.Path
---@param strip boolean?
---@return prefyl.async.Future<string>
return function(path, strip)
    local cache = LUAC_DIR / (path:encode("rfc2396") .. (strip and ".s" or ".d") .. ".luac")
    return async.async(function()
        if path:mtime() < cache:mtime() then
            return assert(cache:read())
        else
            local data = string.dump(assert(loadfile(path:tostring())), strip)
            async.vim.schedule().await()
            assert(cache:ensure_parent_dir():write(data).await())
            return data
        end
    end)
end
