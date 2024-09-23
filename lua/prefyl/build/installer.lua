---@class prefyl.build.InstallProgress
---@field title string
---@field log string?
---@field is_finished boolean

local Git = require("prefyl.build.installer.Git")

local M = {}

---@param config prefyl.build.Config
function M.install(config)
    ---@type prefyl.build.Installer[]
    local installers = vim.iter(config.plugins)
        :map(function(_name, spec) ---@param spec prefyl.build.Config.PluginSpec
            return spec.enabled and spec.url and Git.new(spec.dir, spec.url)
        end)
        :filter(function(i) ---@param i prefyl.build.Installer?
            if i then
                return not i:is_installed()
            else
                return false
            end
        end)
        :totable()

    local working = {} ---@type prefyl.build.Installer[]
    local max_works = vim.uv.available_parallelism()

    while 0 < #installers or 0 < #working do
        for _ = 1, math.min(#installers, max_works - #working) do
            local i = table.remove(installers) ---@type prefyl.build.Installer
            i:install()
            table.insert(working, i)
        end
        vim.wait(250)
        working = vim.iter(working)
            :filter(function(i) ---@param i prefyl.build.Installer
                return not i:progress().is_finished
            end)
            :totable()
    end
end

return M
