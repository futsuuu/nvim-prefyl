---@meta

---@class prefyl.build.Installer
local Installer = {}

---@param dir prefyl.Path
---@param param any
---@return prefyl.build.Installer
function Installer.new(dir, param) end

---@param callback fun(res: boolean)
function Installer:is_installed(callback) end

---@param progress prefyl.build.InstallProgress
function Installer:install(progress) end
