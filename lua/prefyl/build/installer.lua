local async = require("prefyl.lib.async")

local Git = require("prefyl.build.installer.Git")

local M = {}

---@class prefyl.build.InstallProgress
---@field private on_finish fun()
local Progress = {}
---@private
Progress.__index = Progress

---@param callbacks { on_finish: fun() }
function Progress.new(callbacks)
    return setmetatable({
        on_finish = callbacks.on_finish,
    }, Progress)
end

---@param msg string
function Progress:log(msg)
    local _ = msg
end

---@param msg string
function Progress:error(msg)
    local _ = msg
    self.on_finish()
end

function Progress:success()
    self.on_finish()
end

---@param config prefyl.build.Config
---@return prefyl.async.Future<nil>
function M.install(config)
    return async.Future.new(function(finish)
        local installers = {} ---@type prefyl.build.Installer[]
        for _name, spec in pairs(config.plugins) do
            if spec.enabled and spec.url then
                table.insert(installers, Git.new(spec.dir, spec.url))
            end
        end
        local installer_count = #installers

        local done = 0
        local function install()
            local installer = table.remove(installers) ---@type prefyl.build.Installer?
            if not installer then
                return
            end
            local function on_finish()
                done = done + 1
                if done == installer_count then
                    finish()
                else
                    install()
                end
            end
            installer:is_installed(function(res)
                if res then
                    on_finish()
                else
                    installer:install(Progress.new({
                        on_finish = on_finish,
                    }))
                end
            end)
        end
        for _ = 1, vim.uv.available_parallelism() do
            install()
        end
    end)
end

return M
