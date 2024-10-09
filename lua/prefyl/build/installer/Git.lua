local async = require("prefyl.lib.async")

local Base = require("prefyl.build.installer.Base")

---@class prefyl.build.installer.Git: prefyl.build.Installer
---@field private url string
---@field private dir prefyl.Path
---@field private command vim.SystemObj?
---@field private is_finished boolean?
local M = {}
---@private
M.__index = setmetatable(M, Base)

---@param dir prefyl.Path
---@param url string
---@return prefyl.build.Installer
function M.new(dir, url)
    local self = setmetatable({}, M)
    self.dir = dir
    self.url = url
    return self
end

---@return boolean
function M:is_installed()
    -- TODO: async
    return async.block_on(self.dir:exists())
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

---@return prefyl.build.InstallProgress
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
    ---@type prefyl.build.InstallProgress
    return {
        title = self.command and table.concat(self.command.cmd, " ") or "",
        is_finished = is_finished,
    }
end

return M
