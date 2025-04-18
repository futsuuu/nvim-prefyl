local async = require("prefyl.lib.async")
local channel = require("prefyl.lib.channel")
local list = require("prefyl.lib.list")
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
---@return prefyl.Path?
function M.from_debuginfo(info)
    if info.source and info.source:sub(1, 1) == "@" then
        return M.new(info.source:sub(2))
    end
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

---@return string
function M:chunkname()
    return "@" .. self:tostring()
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
    local path, count = self.path:gsub("%.[^%./]+$", extension)
    if count == 0 then
        return M.new(path .. extension)
    else
        return M.new(path)
    end
end

test.test("set_ext", function()
    test.assert_eq(M.new("foo.baz"), M.new("foo"):set_ext("baz"))
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

---@return prefyl.async.Future<boolean?, string?>
function M:create_dir()
    return (async.uv.fs_mkdir(self.path, 493)) -- 0o755
end

---@return prefyl.async.Future<boolean?, string?>
function M:create_dir_all()
    return async.run(function()
        if self:is_dir().await() then
            return true
        end
        local success, err = (self / ".."):create_dir_all().await()
        if not success then
            return nil, err
        end
        return self:create_dir().await()
    end)
end

---@package
---@return prefyl.async.Future<uv.aliases.fs_stat_table?>
function M:stat()
    return async.run(function()
        return (async.uv.fs_stat(self.path).await())
    end)
end

---@return prefyl.async.Future<boolean>
function M:exists()
    return async.run(function()
        return self:stat().await() ~= nil
    end)
end

---@return prefyl.async.Future<boolean>
function M:is_dir()
    return async.run(function()
        local stat = self:stat().await()
        return stat and stat.type == "directory" or false
    end)
end

---@return prefyl.async.Future<string?, string?>: data?, err?
function M:read()
    return async.run(function()
        local fd, err = async.uv.fs_open(self.path, "r", 292).await() -- 0o444
        if not fd then
            return nil, err
        end
        local stat, err = async.uv.fs_fstat(fd).await()
        if not stat then
            return nil, err
        end
        local data, err = async.uv.fs_read(fd, stat.size).await()
        if not data then
            return nil, err
        end
        local success, err = async.uv.fs_close(fd).await()
        if not success then
            return nil, err
        end
        return data
    end)
end

---@class prefyl.Path.ReadDirEntry
---@field path prefyl.Path
---@field type uv.aliases.fs_types

---@return prefyl.async.Future<prefyl.channel.Receiver<prefyl.Path.ReadDirEntry>?, string?>
function M:read_dir()
    return async.run(function()
        local tx, rx = channel.new()

        local dir, err = async.uv.fs_opendir(self.path).await()
        if not dir then
            return nil, err
        end

        async.run(function()
            channel.closed(rx).await()
            assert(dir:closedir().await())
        end)

        while true do
            local entries, _err = dir:readdir().await()
            if not entries then
                channel.close(tx)
                break
            end
            local br = false
            for _, entry in ipairs(entries) do
                ---@type prefyl.Path.ReadDirEntry
                local entry = {
                    path = self / entry.name,
                    type = entry.type,
                }
                br = not tx(entry)
                if br then
                    break
                end
            end
            if br then
                break
            end
        end

        return rx
    end)
end

---@class prefyl.Path.WalkDirEntry: prefyl.Path.ReadDirEntry
---@field depth integer

---@class prefyl.Path.WalkDirOpts
---@field filter (fun(entry: prefyl.Path.WalkDirEntry): boolean)?
---@field min_depth integer?
---@field max_depth integer?

---@param path prefyl.Path
---@param tx prefyl.channel.Sender<prefyl.Path.WalkDirEntry>
---@param opts prefyl.Path.WalkDirOpts
---@param depth integer
---@return prefyl.async.Future<boolean?, string?>
local function walk_dir(path, tx, opts, depth)
    return async.run(function()
        local reader, err = path:read_dir().await()
        if not reader then
            return nil, err
        end

        local futures = {}
        while true do
            local entry = reader().await() ---@type prefyl.Path.ReadDirEntry?
            if not entry then
                break
            end

            ---@type prefyl.Path.WalkDirEntry
            local entry = {
                depth = depth,
                path = entry.path,
                type = entry.type,
            }
            local send = true
            if opts.filter and opts.filter(entry) == false then
                send = false
            end
            if send then
                if (opts.min_depth or 1) <= depth and not tx(entry) then
                    break
                end
                if depth < (opts.max_depth or math.huge) and entry.type == "directory" then
                    local f = async.run(function()
                        return list.pack(walk_dir(entry.path, tx, opts, depth + 1).await())
                    end)
                    table.insert(futures, f)
                end
            end
        end

        for _, result in ipairs(async.join_list(futures).await()) do
            local success, err = list.unpack(result)
            if not success then
                return nil, err
            end
        end

        return true
    end)
end

---@param opts prefyl.Path.WalkDirOpts?
---@return prefyl.channel.Receiver<prefyl.Path.WalkDirEntry>
function M:walk_dir(opts)
    local tx, rx = channel.new()
    async.run(function()
        walk_dir(self, tx, opts or {}, 1).await()
        channel.close(tx)
    end)
    return rx
end

---@return prefyl.async.Future<integer?, string?>: bytes?, err?
function M:write(data)
    return async.run(function()
        local fd, err = async.uv.fs_open(self.path, "w", 420).await() -- 0o644
        if not fd then
            return nil, err
        end
        local bytes, err = async.uv.fs_write(fd, data, 0).await()
        if not bytes then
            return nil, err
        end
        local success, err = async.uv.fs_close(fd).await()
        if not success then
            return nil, err
        end
        return bytes
    end)
end

---@param new prefyl.Path
---@return prefyl.async.Future<boolean?, string?>: success?, err?
function M:link(new)
    return async.run(function()
        local hardlink = false
        local symlink_flags = {} ---@type uv.aliases.fs_symlink_flags
        if IS_WINDOWS then
            hardlink = not self:is_dir().await()
            symlink_flags.junction = true
        end

        if hardlink then
            return async.uv.fs_link(self.path, new.path).await()
        else
            return async.uv.fs_symlink(self.path, new.path, symlink_flags).await()
        end
    end)
end

---@return boolean? success
---@return string? err
function M:remove_file()
    return os.remove(self.path)
end

---@return prefyl.async.Future<boolean?, string?>
function M:remove_link()
    return async.run(function()
        local stat = self:stat().await()
        -- for hardlink
        if stat and stat.type == "file" then
            return self:remove_file()
        end
        return async.uv.fs_unlink(self.path).await()
    end)
end

---@return prefyl.async.Future<boolean?, string?>
function M:remove_dir()
    return (async.uv.fs_rmdir(self.path))
end

---@return prefyl.async.Future<boolean?, string?>
function M:remove_dir_all()
    return async.run(function()
        if not self:exists().await() then
            return true
        end

        local reader, err = self:read_dir().await()
        if not reader then
            return nil, err
        end

        local futures = {}
        while true do
            local entry = reader().await() ---@type prefyl.Path.ReadDirEntry?
            if not entry then
                break
            end
            local future = async.run(function()
                if entry.type == "directory" then
                    return list.pack(entry.path:remove_dir_all().await())
                elseif entry.type == "link" then
                    return list.pack(entry.path:remove_link().await())
                else
                    return list.pack(entry.path:remove_file())
                end
            end)
            table.insert(futures, future)
        end

        for _, result in ipairs(async.join_list(futures).await()) do
            local success, err = list.unpack(result)
            if not success then
                return nil, err
            end
        end

        return self:remove_dir().await()
    end)
end

---@class prefyl.Path.Timestamp
---@field private sec integer
---@field private nsec integer
local Timestamp = {}
---@private
Timestamp.__index = Timestamp

---@param time { sec: integer, nsec: integer }?
---@return prefyl.Path.Timestamp
local function timestamp(time)
    return setmetatable(time or { sec = 0, nsec = 0 }, Timestamp)
end

---@private
---@param other prefyl.Path.Timestamp
---@return boolean
function Timestamp:__eq(other)
    return self.sec == other.sec and self.nsec == other.nsec
end
---@private
---@param other prefyl.Path.Timestamp
---@return boolean
function Timestamp:__lt(other)
    if self.sec == other.sec then
        return self.nsec <= other.nsec
    else
        return self.sec <= other.sec
    end
end
---@private
---@param other prefyl.Path.Timestamp
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

---@return prefyl.async.Future<prefyl.Path.Timestamp>
function M:birthtime()
    return async.run(function()
        local s = self:stat().await()
        return timestamp(s and s.birthtime)
    end)
end

---@return prefyl.async.Future<prefyl.Path.Timestamp>
function M:ctime()
    return async.run(function()
        local s = self:stat().await()
        return timestamp(s and s.ctime)
    end)
end

---@return prefyl.async.Future<prefyl.Path.Timestamp>
function M:mtime()
    return async.run(function()
        local s = self:stat().await()
        return timestamp(s and s.mtime)
    end)
end

---@return prefyl.async.Future<prefyl.Path.Timestamp>
function M:atime()
    return async.run(function()
        local s = self:stat().await()
        return timestamp(s and s.atime)
    end)
end

---@class prefyl.Path.StdPath
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
        async.vim.ensure_scheduled()
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
    assert(assert(M.from_debuginfo(debug.getinfo(1, "S"))):strip_suffix("lua/prefyl/lib/Path.lua"))

return M
