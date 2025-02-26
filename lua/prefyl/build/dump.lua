local Path = require("prefyl.lib.Path")
local async = require("prefyl.lib.async")

---@param path prefyl.Path
---@param strip boolean?
---@return prefyl.async.Future<string>
return function(path, strip)
    return async.run(function()
        local luac_dir = Path.stdpath.cache / "prefyl" / "luac"
        local cache = luac_dir / (path:encode("rfc2396") .. (strip and ".s" or ".d") .. ".luac")
        if path:mtime().await() < cache:mtime().await() then
            return assert(cache:read().await())
        else
            local data = string.dump(assert(loadfile(path:tostring())), strip)
            assert((cache / ".."):create_dir_all().await())
            assert(cache:write(data).await())
            return data
        end
    end)
end
