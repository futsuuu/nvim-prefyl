local Buffer = require("string.buffer")

local Path = require("prefyl.lib.path")

local M = {}

local VERSION = 0
local CACHE_DIR = (Path.stdpath.cache / "prefyl" / "luamodules"):ensure_dir()

---@class prefyl.compiler.dump.Cache
---@field version integer
---@field modules prefyl.compiler.dump.Module[]

---@class prefyl.compiler.dump.Module
---@field path prefyl.Path
---@field dumped string
---@field mtime_sec integer
---@field mtime_nsec integer

---@type string.buffer.serialization.opts
local buf_opts = {
    metatable = { Path },
    dict = { "version", "modules", "path", "dumped", "mtime_sec", "mtime_nsec" },
}
local buf_dec = Buffer.new(nil, buf_opts)
local buf_enc = Buffer.new(nil, buf_opts)

---@param path prefyl.Path
---@param modules prefyl.compiler.dump.Module[]
local function write_cache_file(path, modules)
    local cache = { modules = modules, version = VERSION } ---@type prefyl.compiler.dump.Cache
    local encoded = buf_enc:reset():encode(cache):get()
    vim.uv.fs_open(path:tostring(), "w", 420, function(err, fd) -- 0644
        assert(fd, err)
        vim.uv.fs_write(fd, encoded, nil, function(err)
            assert(not err, err)
            assert(vim.uv.fs_close(fd))
        end)
    end)
end

---@param path prefyl.Path
---@return prefyl.compiler.dump.Module[]?
local function read_cache_file(path)
    local fd = vim.uv.fs_open(path:tostring(), "r", 292) -- 0444
    if not fd then
        return
    end
    local stat = assert(vim.uv.fs_fstat(fd))
    local content = assert(vim.uv.fs_read(fd, stat.size, 0))
    assert(vim.uv.fs_close(fd))
    local cache = assert(buf_dec:set(content):decode()) --[[@as prefyl.compiler.dump.Cache]]
    if cache.version == VERSION then
        return cache.modules
    end
end

---@param id string
---@param lua_files prefyl.Path[]
---@return table<prefyl.Path, string>
function M.dump(id, lua_files)
    local cache_file = CACHE_DIR / id
    local modules = read_cache_file(cache_file) or {}
    local modified = false
    local result = {} ---@type table<prefyl.Path, string>

    for _, lua_file in ipairs(lua_files) do
        local stat = assert(vim.uv.fs_stat(lua_file:tostring()))
        ---@type prefyl.compiler.dump.Module?
        local m = vim.iter(modules):find(function(m) ---@param m prefyl.compiler.dump.Module
            return m.path == lua_file
        end)
        if
            not m
            or m.mtime_sec < stat.mtime.sec
            or (m.mtime_sec == stat.mtime.sec and m.mtime_nsec < stat.mtime.nsec)
        then
            modified = true
            ---@type prefyl.compiler.dump.Module
            m = {
                path = lua_file,
                dumped = string.dump(assert(loadfile(lua_file:tostring()))),
                mtime_sec = stat.mtime.sec,
                mtime_nsec = stat.mtime.nsec,
            }
            table.insert(modules, m)
        end
        result[lua_file] = m.dumped
    end

    if modified then
        ---@type prefyl.compiler.dump.Module[]
        modules = vim.iter(modules)
            :filter(function(m) ---@param m prefyl.compiler.dump.Module
                return vim.list_contains(lua_files, m.path)
            end)
            :totable()
        write_cache_file(cache_file, modules)
    end

    return result
end

return M
