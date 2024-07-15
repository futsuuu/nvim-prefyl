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

plugins.neogit = {
    url = "https://github.com/NeogitOrg/neogit",
    cmd = { "Neogit" },
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
