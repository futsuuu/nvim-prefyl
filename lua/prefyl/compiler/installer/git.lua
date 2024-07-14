local Base = require("prefyl.compiler.installer.base")

---@class prefyl.compiler.installer.Git: prefyl.compiler.Installer
---@field private url string
---@field private dir prefyl.Path
---@field private command vim.SystemObj?
---@field private is_finished boolean?
local M = {}
---@private
M.__index = setmetatable(M, Base)

---@param dir prefyl.Path
---@param url string
---@return prefyl.compiler.Installer
function M.new(dir, url)
    local self = setmetatable({}, M)
    self.dir = dir
    self.url = url
    return self
end

---@return boolean
function M:is_installed()
    return self.dir:exists()
end

function M:install()
    self:_run_hooks_install()
    if self.command then
        error("the process still running!")
    end
    self.command = vim.system(
        { "git", "clone", "--filter=blob:none", self.url, self.dir:tostring() },
        {
            text = true,
            detach = true,
        }
    )
end

---@return prefyl.compiler.InstallProgress
function M:progress()
    local is_finished
    if self.command then
        is_finished = self.command:is_closing()
        if is_finished then
            self:_run_hooks_post_install()
            self.command = nil
        end
    else
        is_finished = true
    end
    ---@type prefyl.compiler.InstallProgress
    return {
        title = self.command and table.concat(self.command.cmd, " ") or "",
        is_finished = is_finished,
    }
end

return M
