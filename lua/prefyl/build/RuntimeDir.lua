local Path = require("prefyl.lib.Path")
local async = require("prefyl.lib.async")
local test = require("prefyl.lib.test")

local dump = require("prefyl.build.dump")

---@param v boolean
---@param l boolean
---@return fun(entry: prefyl.Path.WalkDirEntry): boolean
local function vim_lua(v, l)
    ---@param entry prefyl.Path.WalkDirEntry
    return function(entry)
        if entry.type ~= "file" then
            return true
        end
        local ext = entry.path:ext()
        if v and ext == "vim" then
            return true
        elseif l and ext == "lua" then
            return true
        end
        return false
    end
end

---@type table<prefyl.build.RuntimeDir.DirKind, prefyl.Path.WalkDirOpts>
---@enum (key) prefyl.build.RuntimeDir.DirKind
local walk_opts = {
    -- load when added to `&runtimepath`
    plugin = {
        -- plugin/**/*.{vim,lua}
        filter = vim_lua(true, true),
    },
    -- load when added to `&runtimepath`
    ftdetect = {
        -- ftdetect/*.{vim,lua}
        filter = vim_lua(true, true),
        max_depth = 1,
    },
    -- load when `require()` is called
    lua = {
        -- lua/**/*.lua
        filter = vim_lua(false, true),
    },
    -- load on `ColorSchemePre` event
    colors = {
        -- colors/<amatch>.{vim,lua}
        filter = vim_lua(true, true),
        max_depth = 1,
    },
    -- load on `FileType` event
    indent = {
        -- indent/<amatch>.{vim,lua}
        filter = vim_lua(true, true),
    },
    -- load on `FileType` event
    ftplugin = {
        -- ftplugin/<amatch>.{vim,lua}
        -- ftplugin/<amatch>_*.{vim,lua}
        -- ftplugin/<amatch>/*.{vim,lua}
        filter = vim_lua(true, true),
        max_depth = 2,
    },
    -- load on `Syntax` event
    syntax = {
        -- syntax/<amatch>.{vim,lua}
        -- syntax/<amatch>/*.{vim,lua}
        filter = vim_lua(true, true),
        max_depth = 2,
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

---@class prefyl.build.RuntimeDir
---@field dir prefyl.Path
---@field plugin_files prefyl.Path[]
---@field ftdetect_files prefyl.Path[]
---@field luamodules table<string, string>
---@field colorschemes string[]

local M = {}

---@param dir prefyl.Path
---@return prefyl.async.Future<prefyl.build.RuntimeDir>
function M.new(dir)
    return async.async(function()
        ---@type table<prefyl.build.RuntimeDir.DirKind, prefyl.async.Future<prefyl.Path[]>>
        local files = {}
        for name, opts in pairs(walk_opts) do
            files[name] = async.async(function()
                local walker = assert((dir / name):walk_dir(opts))
                local result = {}
                while true do
                    local entry = walker().await() ---@type prefyl.Path.WalkDirEntry?
                    if not entry then
                        break
                    end
                    if entry.type == "file" then
                        table.insert(result, entry.path)
                    end
                end
                return result
            end)
        end
        ---@type table<prefyl.build.RuntimeDir.DirKind, prefyl.Path[]>
        local files = async.join_all(files).await()

        ---@type prefyl.build.RuntimeDir
        return {
            dir = dir,
            plugin_files = files["plugin"],
            ftdetect_files = files["ftdetect"],
            luamodules = async
                .join_all(vim.iter(files["lua"]):fold({}, function(acc, path) ---@param path prefyl.Path
                    acc[get_luamodule(dir, path)] = dump(path)
                    return acc
                end))
                .await(),
            colorschemes = vim.iter(files["colors"])
                :map(function(path)
                    return get_colorscheme(dir, path)
                end)
                :totable(),
        }
    end)
end

return M
