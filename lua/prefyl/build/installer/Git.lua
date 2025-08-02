local async = require("prefyl.lib.async")

---@class prefyl.build.installer.Git: prefyl.build.Installer
---@field private url string
---@field private dir prefyl.Path
---@field private is_finished boolean?
local M = {}
---@private
M.__index = M

---@param dir prefyl.Path
---@param url string
---@return prefyl.build.Installer
function M.new(dir, url)
    local self = setmetatable({}, M)
    self.dir = dir
    self.url = url
    return self
end

function M:is_installed(callback)
    async.run(function()
        callback(self.dir:exists().await())
    end)
end

function M:install(progress)
    ---@param err string?
    ---@param data string?
    local function output_callback(err, data)
        if err then
            progress:error(err)
        elseif data then
            progress:log(data)
        end
    end
    vim.system(
        { "git", "clone", "--filter=blob:none", self.url, self.dir:tostring() },
        {
            text = true,
            detach = true,
            stdout = output_callback,
            stderr = output_callback,
        },
        function(out)
            if out.signal ~= 0 then
                progress:error("process exited with signal " .. out.signal)
            elseif out.code ~= 0 then
                progress:error("process exited with status " .. out.code)
            else
                progress:success()
            end
        end
    )
end

return M
