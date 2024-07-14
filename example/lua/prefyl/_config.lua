---@type table<string, prefyl.config.PluginSpec>
local plugins = {}

plugins.prefyl = {
    dir = vim.uv.os_homedir() .. "/dev/github.com/futsuuu/nvim-prefyl",
    url = "https://github.com/futsuuu/nvim-prefyl",
}

plugins.kanagawa = {
    url = "https://github.com/rebelot/kanagawa.nvim",
}

plugins.telescope = {
    url = "https://github.com/nvim-telescope/telescope.nvim",
    deps = { "plenary" },
}

plugins.neogit = {
    url = "https://github.com/NeogitOrg/neogit",
}

plugins.lspconfig = {
    url = "https://github.com/neovim/nvim-lspconfig",
}

plugins.plenary = {
    url = "https://github.com/nvim-lua/plenary.nvim",
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
