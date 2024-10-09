local M = {}
package.loaded[...] = M

local uv = require("luv")

local Future = require("prefyl.lib.async.Future")

---@generic A, B
---@param func fun(a: A, b: B)
---@return fun(b: B, a: A)
local function swap(func)
    return function(a, b)
        func(b, a)
    end
end

---@class prefyl.async.uv.Dir
---@field package inner luv_dir_t
local Dir = {}
---@private
Dir.__index = Dir

---@alias prefyl.async.uv.ReadDirEntry { name: string, type: uv.aliases.fs_types }

---@nodiscard
---@param fd integer
---@return prefyl.async.Future<boolean?, string?>: success?, err?
---@return uv_fs_t
function M.fs_close(fd)
    return Future.new(function(finish)
        return uv.fs_close(fd, swap(finish))
    end)
end

---@param dir prefyl.async.uv.Dir
---@return prefyl.async.Future<boolean?, string?>: success?, err?
---@return uv_fs_t
function M.fs_closedir(dir)
    return Future.new(function(finish)
        return uv.fs_closedir(dir.inner, swap(finish))
    end)
end
Dir.closedir = M.fs_closedir

---@nodiscard
---@param fd integer
---@return prefyl.async.Future<uv.aliases.fs_stat_table?, string?>: stat?, err?
---@return uv_fs_t
function M.fs_fstat(fd)
    return Future.new(function(finish)
        return uv.fs_fstat(fd, swap(finish))
    end)
end

---@nodiscard
---@param path string
---@param new_path string
---@return prefyl.async.Future<boolean?, string?>: success?, err?
---@return uv_fs_t
function M.fs_link(path, new_path)
    return Future.new(function(finish)
        return uv.fs_link(path, new_path, swap(finish))
    end)
end

---@param path string
---@param mode integer
---@return prefyl.async.Future<boolean?, string?>: success?, err?
---@return uv_fs_t
function M.fs_mkdir(path, mode)
    return Future.new(function(finish)
        return uv.fs_mkdir(path, mode, swap(finish))
    end)
end

---@nodiscard
---@param path string
---@param flags integer | uv.aliases.fs_access_flags
---@param mode integer
---@return prefyl.async.Future<integer?, string?>: fd?, err?
---@return uv_fs_t
function M.fs_open(path, flags, mode)
    return Future.new(function(finish)
        return uv.fs_open(path, flags, mode, swap(finish))
    end)
end

---@nodiscard
---@param path string
---@return prefyl.async.Future<prefyl.async.uv.Dir?, string?>: dir?, err?
---@return uv_fs_t
function M.fs_opendir(path)
    return Future.new(function(finish) ---@diagnostic disable-line: return-type-mismatch
        return uv.fs_opendir(path, function(err, dir)
            finish(dir and setmetatable({ inner = dir }, Dir), err)
        end)
    end)
end

---@nodiscard
---@param fd integer
---@param size integer
---@param offset integer?
---@return prefyl.async.Future<string?, string?>: data?, err?
---@return uv_fs_t
function M.fs_read(fd, size, offset)
    return Future.new(function(finish)
        return uv.fs_read(fd, size, offset, swap(finish))
    end)
end

---@nodiscard
---@param dir prefyl.async.uv.Dir
---@return prefyl.async.Future<prefyl.async.uv.ReadDirEntry[]?, string?>: entries?, err?
---@return uv_fs_t
function M.fs_readdir(dir)
    return Future.new(function(finish)
        return uv.fs_readdir(dir.inner, swap(finish))
    end)
end
Dir.readdir = M.fs_readdir

---@nodiscard
---@param path string
---@return prefyl.async.Future<string?, string?>: path?, err?
---@return uv_fs_t
function M.fs_realpath(path)
    return Future.new(function(finish)
        return uv.fs_realpath(path, swap(finish))
    end)
end

---@nodiscard
---@param path string
---@return prefyl.async.Future<boolean?, string?>: success?, err?
---@return uv_fs_t
function M.fs_rmdir(path)
    return Future.new(function(finish)
        return uv.fs_rmdir(path, swap(finish))
    end)
end

---@nodiscard
---@param path string
---@return prefyl.async.Future<uv.aliases.fs_stat_table?, string?>: stat?, err?
---@return uv_fs_t
function M.fs_stat(path)
    return Future.new(function(finish)
        return uv.fs_stat(path, swap(finish))
    end)
end

---@nodiscard
---@param path string
---@param new_path string
---@param flags integer | uv.aliases.fs_symlink_flags
---@return prefyl.async.Future<boolean?, string?>: success?, err?
---@return uv_fs_t
function M.fs_symlink(path, new_path, flags)
    return Future.new(function(finish)
        return uv.fs_symlink(path, new_path, flags, swap(finish))
    end)
end

---@nodiscard
---@param path string
---@return prefyl.async.Future<boolean?, string?>: success?, err?
---@return uv_fs_t
function M.fs_unlink(path)
    return Future.new(function(finish)
        return uv.fs_unlink(path, swap(finish))
    end)
end

---@nodiscard
---@param fd integer
---@param data uv.aliases.buffer
---@param offset integer?
---@return prefyl.async.Future<integer?, string?>: bytes?, err?
---@return uv_fs_t
function M.fs_write(fd, data, offset)
    return Future.new(function(finish)
        return uv.fs_write(fd, data, offset, swap(finish))
    end)
end

return M
