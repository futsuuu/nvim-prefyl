#!/usr/bin/env -S nvim -l

if not vim.uv.fs_stat("libs") then
    vim.cmd(
        "!git clone "
            .. "--depth=1 --branch=stable --no-checkout "
            .. "https://github.com/neovim/neovim libs/neovim"
    )
    vim.cmd("!git -C libs/neovim sparse-checkout set runtime/lua")
    vim.cmd("!git -C libs/neovim checkout")

    vim.cmd("!git clone --depth=1 https://github.com/Bilal2453/luvit-meta.git libs/luvit")
    vim.fn.mkdir("libs/luv/library", "p")
    assert(vim.uv.fs_link("libs/luvit/library/uv.lua", "libs/luv/library/luv.lua"))
end

local config = {
    runtime = {
        version = "LuaJIT",
        pathStrict = true,
        path = { "?.lua", "?/init.lua" },
    },
    workspace = {
        checkThirdParty = false,
        library = {
            "lua",
            "libs/neovim/runtime/lua",
            "libs/luv/library",
        },
    },
    diagnostics = {
        unusedLocalExclude = { "_*" },
        disable = { "redefined-local" },
    },
}

local f = assert(io.open(".luarc.json", "w"))
assert(f:write(vim.json.encode(config)))
assert(f:close())
