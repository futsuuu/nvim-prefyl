---@class prefyl.build.Installer
---@field private hooks_install function[]
---@field private hooks_post_install function[]
local M = {}
---@private
M.__index = M

---@param dir prefyl.Path
---@param param any
---@return prefyl.build.Installer
---@diagnostic disable-next-line: unused-local
function M.new(dir, param)
    return setmetatable({}, M)
end

---@return boolean
---@diagnostic disable-next-line: unused-local
function M:is_installed()
    return true
end

function M:install() end

---@return prefyl.build.InstallProgress
function M:progress()
    ---@type prefyl.build.InstallProgress
    return {
        title = "dummy",
        is_finished = true,
    }
end

---@param f function
function M:add_hook_install(f)
    self.hooks_install = self.hooks_install or {}
    table.insert(self.hooks_install, f)
end

---@param f function
function M:add_hook_post_install(f)
    self.hooks_post_install = self.hooks_post_install or {}
    table.insert(self.hooks_post_install, f)
end

---@protected
function M:_run_hooks_install()
    for _, f in ipairs(self.hooks_install or {}) do
        f()
    end
end

---@protected
function M:_run_hooks_post_install()
    for _, f in ipairs(self.hooks_post_install or {}) do
        f()
    end
end

return M
