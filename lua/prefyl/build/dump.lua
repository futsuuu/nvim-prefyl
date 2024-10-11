local Path = require("prefyl.lib.Path")
local async = require("prefyl.lib.async")
local result = require("prefyl.lib.result")

---@param path prefyl.Path
---@param strip boolean?
---@return prefyl.async.Future<prefyl.Result<string, string>>
return function(path, strip)
    return async.async(result.wrap(function()
        local luac_dir = Path.stdpath.cache / "prefyl" / "luac"
        local cache = luac_dir / (path:encode("rfc2396") .. (strip and ".s" or ".d") .. ".luac")
        if path:mtime().await() < cache:mtime().await() then
            return result.ok(assert(cache:read().await()))
        else
            local data = string.dump(assert(loadfile(path:tostring())), strip)
            cache:join(".."):create_dir_all().await().ensure()
            assert(cache:write(data).await())
            return result.ok(data)
        end
    end))
end
