local Path = require("prefyl.lib.Path")
local async = require("prefyl.lib.async")

---@class prefyl.build.Out
---@field package strip boolean
---@field package dir prefyl.Path
---@field package counter integer
---@field package last prefyl.Path?
local M = {}
---@private
M.__index = M

---@param strip boolean
---@return prefyl.async.Future<prefyl.build.Out>
function M.new(strip)
    return async.async(function()
        local self = setmetatable({}, M)
        self.strip = strip
        self.dir = Path.stdpath.state / "prefyl" / (strip and "s" or "d")
        self.counter = 0
        self.last = nil
        assert(self.dir:remove_dir_all().await())
        assert(self.dir:create_dir_all().await())
        return self
    end)
end

---@return prefyl.async.Future<prefyl.Path>
function M:finish()
    return async.async(function()
        local last = assert(self.last)
        local link = Path.stdpath.state / "prefyl" / "startup"
        if link:exists().await() then
            assert(link:remove_link().await())
        end
        assert(last:link(link).await())
        return link
    end)
end

---@param str string
---@return prefyl.async.Future<prefyl.Path>
function M:write(str)
    self.counter = self.counter + 1
    local counter = self.counter
    return async.async(function()
        local s ---@type string
        if self.strip then
            s = string.dump(assert(loadstring(str)), true)
        else
            s = "-- vim:ft=lua:readonly:nowrap\n" .. str:gsub("\\\n", "\\n")
        end
        local path = self.dir / ("%x"):format(counter)
        assert(path:write(s).await())

        self.last = path
        return path
    end)
end

return M
