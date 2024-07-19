local Path = require("prefyl.lib.path")
local test = require("prefyl.lib.test")

local dumper = require("prefyl.compiler.dumper")

---@enum prefyl.rtpath.DirKind
local DirKind = {
    PLUGIN = 1,
    FTDETECT = 2,
    LUA = 3,
    COLORS = 4,
    INDENT = 5,
    FTPLUGIN = 6,
    SYNTAX = 7,
}

---@type table<prefyl.rtpath.DirKind, string[]>
local patterns = {
    -- load when added to `&runtimepath`
    [DirKind.PLUGIN] = { "plugin/**/*.{vim,lua}" },
    -- load when added to `&runtimepath`
    [DirKind.FTDETECT] = { "ftdetect/*.{vim,lua}" },
    -- load when `require()` is called
    [DirKind.LUA] = { "lua/**/*.lua" },
    -- load on `ColorSchemePre` event
    [DirKind.COLORS] = {
        -- colors/<amatch>.{vim,lua}
        "colors/*.{vim,lua}",
    },
    -- load on `FileType` event
    [DirKind.INDENT] = {
        -- indent/<amatch>.{vim,lua}
        "indent/*.{vim,lua}",
    },
    -- load on `FileType` event
    [DirKind.FTPLUGIN] = {
        -- ftplugin/<amatch>.{vim,lua}
        -- ftplugin/<amatch>_*.{vim,lua}
        "ftplugin/*.{vim,lua}",
        -- ftplugin/<amatch>/*.{vim,lua}
        "ftplugin/*/*.{vim,lua}",
    },
    -- load on `Syntax` event
    [DirKind.SYNTAX] = {
        -- syntax/<amatch>.{vim,lua}
        "syntax/*.{vim,lua}",
        -- syntax/<amatch>/*.{vim,lua}
        "syntax/*/*.{vim,lua}",
    },
}

---@param basedir prefyl.Path
---@param path prefyl.Path
---@return string
local function get_luamodule(basedir, path)
    return (
        assert(path:strip_prefix(basedir / "lua"))
            :set_ext("")
            :tostring()
            :gsub("[/\\]init", "")
            :gsub("[/\\]", ".")
    )
end

test.test("get_luamodule", function()
    test.assert_eq(
        "foo.bar",
        get_luamodule(Path.new("/plugin"), Path.new("/plugin/lua/foo/bar.lua"))
    )
    test.assert_eq(
        "bar.baz",
        get_luamodule(Path.new("/plugin"), Path.new("/plugin/lua/bar/baz/init.lua"))
    )
end)

---@param basedir prefyl.Path
---@param path prefyl.Path
---@return string
local function get_colorscheme(basedir, path)
    return assert(path:strip_prefix(basedir / "colors")):set_ext(""):tostring()
end

test.test("get_colorscheme", function()
    test.assert_eq("foo", get_colorscheme(Path.new("/plugin"), Path.new("/plugin/colors/foo.vim")))
    test.assert_eq("bar", get_colorscheme(Path.new("/plugin"), Path.new("/plugin/colors/bar.lua")))
end)

---@class prefyl.compiler.RuntimeDir
---@field dir prefyl.Path
---@field plugin_files prefyl.Path[]
---@field ftdetect_files prefyl.Path[]
---@field luamodules table<string, string>
---@field colorschemes string[]
local M = {}

---@param dir prefyl.Path
---@return prefyl.compiler.RuntimeDir
function M.new(dir)
    local files = {} ---@type table<prefyl.rtpath.DirKind, prefyl.Path[]>
    for kind, ps in pairs(patterns) do
        files[kind] = vim.iter(ps)
            :map(function(p)
                return dir:glob(p)
            end)
            :flatten()
            :totable()
    end

    local dumped_modules =
        dumper.dump(vim.uri_encode(dir:tostring(), "rfc2396"), files[DirKind.LUA])
    ---@type prefyl.compiler.RuntimeDir
    return {
        dir = dir,
        plugin_files = files[DirKind.PLUGIN],
        ftdetect_files = files[DirKind.FTDETECT],
        luamodules = vim.iter(files[DirKind.LUA]):fold({}, function(acc, path)
            acc[get_luamodule(dir, path)] = dumped_modules[path]
            return acc
        end),
        colorschemes = vim.iter(files[DirKind.COLORS])
            :map(function(path)
                return get_colorscheme(dir, path)
            end)
            :totable(),
    }
end

return M
