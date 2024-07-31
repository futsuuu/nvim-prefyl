---@type table<string, prefyl.config.PluginSpec>
local plugins = {}

plugins.prefyl = {
    dir = vim.uv.os_homedir() .. "/dev/github.com/futsuuu/nvim-prefyl",
    url = "https://github.com/futsuuu/nvim-prefyl",
}

plugins.kanagawa = {
    url = "https://github.com/rebelot/kanagawa.nvim",
    lazy = true,
}

plugins.telescope = {
    url = "https://github.com/nvim-telescope/telescope.nvim",
    deps = { "plenary" },
    cmd = { "Telescope" },
}

plugins.cmp = {
    url = "https://github.com/hrsh7th/nvim-cmp",
    lazy = true,
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

plugins.cmp_buffer = {
    url = "https://github.com/hrsh7th/cmp-buffer",
    deps = { "cmp" },
    event = { "InsertEnter" },
}

plugins.cmp_cmdline = {
    url = "https://github.com/hrsh7th/cmp-cmdline",
    deps = { "cmp" },
    event = { "CmdlineEnter" },
}

plugins.neogit = {
    url = "https://github.com/NeogitOrg/neogit",
    deps = { "plenary" },
    cmd = { "Neogit" },
    config = function()
        require("neogit").setup({})
    end,
}

plugins.lspconfig = {
    url = "https://github.com/neovim/nvim-lspconfig",
    lazy = true,
}

plugins.plenary = {
    url = "https://github.com/nvim-lua/plenary.nvim",
    lazy = true,
}

return {
    plugins = plugins,
    -- vimruntime = {
    --     disabled_plugins = {
    --         "matchit",
    --         "rplugin",
    --         "gzip",
    --         "tarPlugin",
    --         "zipPlugin",
    --         "tohtml",
    --         "tutor",
    --     },
    -- },
}
