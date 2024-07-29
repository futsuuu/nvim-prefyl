local Path = require("prefyl.lib.path")

local LUAC_DIR = Path.stdpath.cache / "prefyl" / "luac"

---@param path prefyl.Path
---@param strip boolean?
---@return string
return function(path, strip)
    local cache = LUAC_DIR / (path:encode("rfc2396") .. (strip and ".s" or ".d") .. ".luac")
    if path:mtime() < cache:mtime() then
        return assert(cache:read())
    else
        local data = string.dump(assert(loadfile(path:tostring())), strip)
        cache:ensure_parent_dir():write(data, assert)
        return data
    end
end
