local Path = require("prefyl.lib.path")

---@class prefyl.build.Out
---@field private strip boolean
---@field private dir prefyl.Path
---@field private counter integer
---@field private last prefyl.Path?
local M = {}
---@private
M.__index = M

---@param strip boolean
---@return prefyl.build.Out
function M.new(strip)
    ---@type prefyl.build.Out
    local self = {
        strip = strip,
        dir = (Path.stdpath.state / "prefyl" / (strip and "s" or "d")):ensure_dir(),
        counter = 0,
        last = nil,
    }
    self.dir:remove_all()
    self.dir:ensure_dir()
    return setmetatable(self, M)
end

---@return prefyl.Path
function M:finish()
    local last = assert(self.last)
    local link = Path.stdpath.state / "prefyl" / (self.strip and "main.luac" or "main.lua")
    assert(link:remove())
    assert(last:link(link))
    return link
end

---@param str string
---@return prefyl.Path
function M:write(str)
    local s ---@type string
    if self.strip then
        s = string.dump(assert(loadstring(str)), true)
    else
        s = "-- vim:ft=lua:readonly:nowrap\n" .. str:gsub("\\\n", "\\n")
    end
    local path = self.dir / ("%x"):format(self.counter)
    assert(path:write(s))

    self.last = path
    self.counter = self.counter + 1
    return path
end

return M
