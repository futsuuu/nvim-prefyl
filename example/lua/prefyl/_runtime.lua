---@type prefyl._runtime
local config = {
    plugins = {},
}
local plugins = config.plugins

plugins.cmp = {
    config = function()
        local cmp = require("cmp")
        cmp.setup({
            sources = {
                { name = "buffer" },
            },
        })
        cmp.setup.cmdline(":", {
            mapping = cmp.mapping.preset.cmdline(),
            sources = cmp.config.sources({
                { name = "cmdline" },
            }),
        })
    end,
}

plugins.neogit = {
    config = function()
        require("neogit").setup({})
    end,
}

return config
