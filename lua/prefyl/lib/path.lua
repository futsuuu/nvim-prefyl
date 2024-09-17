local test = require("prefyl.lib.test")

---@class prefyl.Path
---@operator div(string | prefyl.Path): prefyl.Path
---@field package path string
local M = {}
---@private
M.__index = M

local SEPARATOR = package.config:sub(1, 1)
local IS_WINDOWS = SEPARATOR == "\\"

---@return string
function M.separator()
    return SEPARATOR
end

---@param path string | prefyl.Path
---@return prefyl.Path
function M.new(path)
    if type(path) == "string" then
        local self = setmetatable({}, M)
        self.path = path
        return self:normalize()
    elseif getmetatable(path) == M then
        ---@cast path prefyl.Path
        return path
    end
    error("expected a `string` or an instance of `prefyl.Path`, got " .. vim.inspect(path))
end

test.group("new", function()
    test.test("invalid argument", { fail = true }, function()
        M.new(1) ---@diagnostic disable-line
    end)
end)

---@param path any
---@return prefyl.Path?
function M.try_new(path)
    local success, path = pcall(M.new, path)
    return success and path or nil
end

---@param info debuginfo
---@return prefyl.Path
function M.from_debuginfo(info)
    return M.new(info.source and info.source:gsub("^@", ""))
end

---@private
function M:__tostring()
    return self:tostring()
end

test.test("format", function()
    test.assert_eq("path", string.format("%s", M.new("path")))
    test.assert_eq('"path"', string.format("%q", M.new("path")))
end)

---@private
---@param other string | prefyl.Path
---@return boolean
function M:__eq(other)
    local other = M.try_new(other)
    return other and self.path == other.path or false
end

test.group("equal operator", function()
    test.test("vim.list_contains", function()
        vim.list_contains({ M.new("p") }, M.new("p"))
    end)

    test.test("test.assert_eq", function()
        test.assert_eq(M.new("p"), M.new("p"))
    end)
end)

---@private
---@param other string | prefyl.Path
---@return boolean
function M:__le(other)
    local other = M.try_new(other)
    return other and self.path <= other.path or false
end
---@private
---@param other string | prefyl.Path
---@return boolean
function M:__lt(other)
    local other = M.try_new(other)
    return other and self.path < other.path or false
end

---@private
---@param other string | prefyl.Path
---@return prefyl.Path
function M:__div(other)
    return self:join(other)
end

test.test("div operator", function()
    test.assert_eq(M.new("foo/bar/baz"), M.new("foo") / "bar" / "baz")
end)

---@private
---@return self
function M:normalize()
    self.path = self.path:gsub("[/\\]+", "/"):gsub("[^/]+/%.%./?", ""):gsub("/+$", "")
    return self
end

test.group("normalize", function()
    test.test("empty component", function()
        test.assert_eq(M.new("foo"), M.new("foo") / "" / "\\/" / "/")
    end)

    test.test("remove double dots", function()
        test.assert_eq(M.new("foo"), M.new("foo") / "bar" / "..")
        test.assert_eq(M.new(""), M.new("foo") / "..")
        test.assert_eq(M.new(".."), M.new("foo") / ".." / "..")
    end)
end)

---@return string
function M:tostring()
    if SEPARATOR == "/" then
        return self.path
    else
        return (self.path:gsub("/", SEPARATOR))
    end
end

---@param ... string | prefyl.Path
---@return prefyl.Path
function M:join(...)
    local components = vim.iter({ self.path, ... })
        :map(tostring)
        :filter(function(component) ---@param component string
            return 0 < component:len()
        end)
        :map(M.new)
        :map(function(path) ---@param path prefyl.Path
            return path.path
        end)
        :totable()
    return M.new(table.concat(components, "/"))
end

---@param p string
---@param prefix string
---@return boolean
local function starts_with(p, prefix)
    if IS_WINDOWS then
        p, prefix = p:lower(), prefix:lower()
    end
    local prefix_len = prefix:len()
    if p:sub(1, prefix_len) ~= prefix then
        return false
    end
    local next = p:sub(prefix_len + 1, prefix_len + 1)
    return next == "/" or next == ""
end

test.test("starts_with", function()
    assert(starts_with("/foo/bar/baz", "/foo"))
    assert(not starts_with("/foo/bar/baz", "/foo/ba"))
end)

---@param p string
---@param suffix string
---@return boolean
local function ends_with(p, suffix)
    if IS_WINDOWS then
        p, suffix = p:lower(), suffix:lower()
    end
    local suffix_len = suffix:len()
    if p:sub(-suffix_len) ~= suffix then
        return false
    end
    local prev = p:sub(-suffix_len - 1, -suffix_len - 1)
    return prev == "/" or prev == ""
end

test.test("ends_with", function()
    assert(ends_with("/foo/bar/baz", "baz"))
    assert(ends_with("/foo/bar/baz", "foo/bar/baz"))
    assert(not ends_with("foo/bar/baz", "ar/baz"))

    assert(ends_with("/foo/bar/baz", "/foo/bar/baz"))
    assert(not ends_with("foo/bar/baz", "/bar/baz"))

    assert(ends_with(".txt", ".txt"))
    assert(not ends_with("foo.txt", ".txt"))
end)

---@param prefix string | prefyl.Path
---@return boolean
function M:starts_with(prefix)
    return starts_with(self.path, M.new(prefix).path)
end

---@param suffix string | prefyl.Path
---@return boolean
function M:ends_with(suffix)
    return ends_with(self.path, M.new(suffix).path)
end

---@param prefix string | prefyl.Path
---@return prefyl.Path?
function M:strip_prefix(prefix)
    local p, prefix = self.path, M.new(prefix).path
    if starts_with(p, prefix) then
        return M.new(p:sub(prefix:len() + 1):gsub("^/", ""))
    end
end

test.test("strip_prefix", function()
    test.assert_eq(M.new("baz"), M.new("foo/bar/baz"):strip_prefix("foo/bar"))
end)

---@param suffix string | prefyl.Path
---@return prefyl.Path?
function M:strip_suffix(suffix)
    local p, suffix = self.path, M.new(suffix).path
    if ends_with(p, suffix) then
        return M.new(p:sub(1, -suffix:len() - 1))
    end
end

test.test("strip_suffix", function()
    test.assert_eq(M.new("foo"), M.new("foo/bar/baz"):strip_suffix("bar/baz"))
end)

---@return string?
function M:ext()
    return self.path:match("%.([^%./]+)$")
end

test.test("ext", function()
    test.assert_eq("txt", M.new("foo.txt"):ext())
    test.assert_eq("gz", M.new("foo.tar.gz"):ext())
    test.assert_eq(nil, M.new("foo"):ext())
end)

---@param extension string
---@return prefyl.Path
function M:set_ext(extension)
    extension = extension:gsub("^%.*(.)", ".%1")
    return M.new(self.path:gsub("%.[^%./]+$", extension))
end

test.test("set_ext", function()
    test.assert_eq(M.new("foo.baz"), M.new("foo.bar"):set_ext("baz"))
    test.assert_eq(M.new("foo.bar.baz"), M.new("foo.bar"):set_ext("bar.baz"))
    test.assert_eq(M.new("foo"), M.new("foo.bar"):set_ext(""))
    test.assert_eq(M.new("foo"), M.new("foo"):set_ext(""))
end)

---@param rfc ("rfc2396" | "rfc2732" | "rfc3986")?
---@return string
function M:encode(rfc)
    return vim.uri_encode(self.path, rfc)
end

---@return self
function M:ensure_dir()
    vim.fn.mkdir(self.path, "p")
    return self
end

---@return self
function M:ensure_parent_dir()
    (self / ".."):ensure_dir()
    return self
end

---@protected
---@return uv.aliases.fs_stat_table?
function M:stat()
    return vim.uv.fs_stat(self.path)
end

---@return boolean
function M:exists()
    return self:stat() ~= nil
end

---@return boolean
function M:is_dir()
    local stat = self:stat()
    return stat and stat.type == "directory" or false
end

---@param expr string
---@return prefyl.Path[]
function M:glob(expr)
    return vim.iter(vim.fn.glob(self.path .. "/" .. expr, false, true)):map(M.new):totable()
end

---@param path string
---@param callback fun(data: string?, err: string?)
local function read(path, callback)
    vim.uv.fs_open(path, "r", 292, function(err, fd) -- 0444
        if not fd then
            callback(nil, err)
            return
        end
        vim.uv.fs_fstat(fd, function(err, stat)
            if not stat then
                callback(nil, err)
                return
            end
            vim.uv.fs_read(fd, stat.size, 0, function(err, data)
                if not data then
                    callback(nil, err)
                    return
                end
                vim.uv.fs_close(fd, function(err, success)
                    if not success then
                        callback(nil, err)
                        return
                    end
                    callback(data)
                end)
            end)
        end)
    end)
end

---@param path string
---@return string? data
---@return string? error
local function read_sync(path)
    local fd, err = vim.uv.fs_open(path, "r", 292) -- 0444
    if not fd then
        return nil, err
    end
    local stat, err = vim.uv.fs_fstat(fd)
    if not stat then
        return nil, err
    end
    local data, err = vim.uv.fs_read(fd, stat.size)
    if not data then
        return nil, err
    end
    local success, err = vim.uv.fs_close(fd)
    if not success then
        return nil, err
    end
    return data
end

---@overload fun(self: prefyl.Path, callback: fun(data: string?, err: string?))
---@overload fun(self: prefyl.Path): data: string?, error: string?
function M:read(callback)
    if callback then
        read(self.path, callback)
    else
        return read_sync(self.path)
    end
end

---@param path string
---@param data string
---@param callback fun(bytes: integer?, err: string?)
local function write(path, data, callback)
    vim.uv.fs_open(path, "w", 420, function(err, fd) -- 0644
        if not fd then
            callback(nil, err)
            return
        end
        vim.uv.fs_write(fd, data, 0, function(err, bytes)
            if not bytes then
                callback(nil, err)
                return
            end
            vim.uv.fs_close(fd, function(err, success)
                if not success then
                    callback(nil, err)
                    return
                end
                callback(bytes)
            end)
        end)
    end)
end

---@param path string
---@param data string
---@return integer? bytes
---@return string? error
local function write_sync(path, data)
    local fd, err = vim.uv.fs_open(path, "w", 420) -- 0644
    if not fd then
        return nil, err
    end
    local bytes, err = vim.uv.fs_write(fd, data, 0)
    if not bytes then
        return nil, err
    end
    local success, err = vim.uv.fs_close(fd)
    if not success then
        return nil, err
    end
    return bytes
end

---@overload fun(self: prefyl.Path, data: string, callback: fun(bytes: integer?, err: string?))
---@overload fun(self: prefyl.Path, data: string): bytes: integer?, error: string?
function M:write(data, callback)
    if callback then
        write(self.path, data, callback)
    else
        return write_sync(self.path, data)
    end
end

---@overload fun(self: prefyl.Path, new: prefyl.Path, callback: fun(success: boolean?, err: string?))
---@overload fun(self: prefyl.Path, new: prefyl.Path): success: boolean?, error: string?
function M:link(new, callback)
    ---@param err string?
    ---@param success boolean?
    local callback = callback and function(err, success)
        callback(success, err)
    end

    local hardlink = false
    local symlink_flags = nil ---@type uv.aliases.fs_symlink_flags?
    if IS_WINDOWS then
        hardlink = not self:is_dir()
        symlink_flags = { junction = true }
    end

    if callback then
        if hardlink then
            vim.uv.fs_link(self.path, new.path, callback)
        else
            vim.uv.fs_symlink(self.path, new.path, symlink_flags, callback)
        end
    else
        local success, err
        if hardlink then
            success, err = vim.uv.fs_link(self.path, new.path)
        else
            success, err = vim.uv.fs_symlink(self.path, new.path, symlink_flags)
        end
        return success, err
    end
end

---@return boolean?
---@return string?
function M:remove()
    if not self:exists() then
        return true
    end
    local rc = vim.fn.delete(self.path, "d")
    if rc == 0 or rc == false then
        return true
    else
        return nil, "faield to remove a file or directory: " .. self.path
    end
end

---@return boolean?
---@return string?
function M:remove_all()
    if not self:exists() then
        return true
    end
    local rc = vim.fn.delete(self.path, "rf")
    if rc == 0 or rc == false then
        return true
    else
        return nil, "faield to remove a file or directory: " .. self.path
    end
end

---@class prefyl.path.Timestamp
---@field private sec integer
---@field private nsec integer
local Timestamp = {}
---@private
Timestamp.__index = Timestamp

---@param time { sec: integer, nsec: integer }?
---@return prefyl.path.Timestamp
local function timestamp(time)
    return setmetatable(time or { sec = 0, nsec = 0 }, Timestamp)
end

---@private
---@param other prefyl.path.Timestamp
---@return boolean
function Timestamp:__eq(other)
    return self.sec == other.sec and self.nsec == other.nsec
end
---@private
---@param other prefyl.path.Timestamp
---@return boolean
function Timestamp:__lt(other)
    if self.sec == other.sec then
        return self.nsec <= other.nsec
    else
        return self.sec <= other.sec
    end
end
---@private
---@param other prefyl.path.Timestamp
---@return boolean
function Timestamp:__le(other)
    if self.sec == other.sec then
        return self.nsec < other.nsec
    else
        return self.sec < other.sec
    end
end

test.test("timestamp", function()
    assert(timestamp({ sec = 0, nsec = 1 }) < timestamp({ sec = 1, nsec = 5 }))
    assert(timestamp({ sec = 1, nsec = 6 }) > timestamp({ sec = 1, nsec = 5 }))
    test.assert_eq(timestamp({ sec = 0, nsec = 1 }), timestamp({ sec = 0, nsec = 1 }))
end)

---@return prefyl.path.Timestamp
function M:birthtime()
    local s = self:stat()
    return timestamp(s and s.birthtime)
end

---@return prefyl.path.Timestamp
function M:ctime()
    local s = self:stat()
    return timestamp(s and s.ctime)
end

---@return prefyl.path.Timestamp
function M:mtime()
    local s = self:stat()
    return timestamp(s and s.mtime)
end

---@return prefyl.path.Timestamp
function M:atime()
    local s = self:stat()
    return timestamp(s and s.atime)
end

---@class prefyl.path.StdPath
---@field cache prefyl.Path
---@field config prefyl.Path
---@field data prefyl.Path
---@field log prefyl.Path
---@field run prefyl.Path
---@field state prefyl.Path
---@field config_dirs prefyl.Path[]
---@field data_dirs prefyl.Path[]
M.stdpath = setmetatable({}, {
    __index = function(t, key)
        local path = vim.fn.stdpath(key)
        local result
        if type(path) == "string" then
            result = M.new(path)
        else
            result = vim.iter(path):map(M.new):totable()
        end

        rawset(t, key, result)
        return result
    end,
})

test.test("stdpath", function()
    assert(not vim.islist(M.stdpath.config))
    assert(vim.islist(M.stdpath.config_dirs))
end)

M.prefyl_root =
    assert(M.from_debuginfo(debug.getinfo(1, "S")):strip_suffix("lua/prefyl/lib/path.lua"))

return M
