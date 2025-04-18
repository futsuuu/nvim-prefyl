local M = {}

---@type table<string, function>
local plugin_loaders = {}
---@type table<string, function>
local after_plugin_loaders = {}

---@type table<string, function[]>
local handler_interrupters = {}

---@param plugin_name string
function M.load_plugin(plugin_name)
    local loader = plugin_loaders[plugin_name]
    if loader then
        plugin_loaders[plugin_name] = nil
        local interrupters = handler_interrupters[plugin_name]
        if interrupters then
            for _, interrupter in ipairs(interrupters) do
                interrupter()
            end
        end
        return loader()
    end
end

---@param plugin_name string
function M.load_after_plugin(plugin_name)
    local loader = after_plugin_loaders[plugin_name]
    if loader then
        after_plugin_loaders[plugin_name] = nil
        return loader()
    end
end

---@param plugin_name string
---@param loader function
---@param after_loader function
function M.set_plugin_loader(plugin_name, loader, after_loader)
    plugin_loaders[plugin_name] = loader
    after_plugin_loaders[plugin_name] = after_loader
end

-- key: module name
-- val: binary chunk
---@type table<string, string>
local luachunks = {}
-- key: module name
-- val: plugin name
---@type table<string, string>
local luamodule_owners = {}

---@param module_name string
---@return string | function
table.insert(package.loaders, 2, function(module_name)
    local plugin_name = luamodule_owners[module_name]
    if plugin_name then
        M.load_plugin(plugin_name)
        M.load_after_plugin(plugin_name)
    end
    local chunk = luachunks[module_name]
    if not chunk then
        return ("\n\tno cache '%s'"):format(module_name)
    end
    local chunk, err = loadstring(chunk)
    return chunk or ("\n\t%s"):format(err)
end)

---@param module_name string
---@param chunk string
function M.set_luachunk(module_name, chunk)
    luachunks[module_name] = chunk
end

---@param plugin_name string
---@param module_name string
function M.handle_luamodule(plugin_name, module_name)
    luamodule_owners[module_name] = plugin_name
end

---@param plugin_name string
---@return function
local function get_plugin_loader(plugin_name)
    return function()
        M.load_plugin(plugin_name)
        M.load_after_plugin(plugin_name)
    end
end

---@param plugin_name string
---@param fn function?
local function insert_handler_interrupter(plugin_name, fn)
    if not fn then
        return
    end
    local interrupters = handler_interrupters[plugin_name]
    if interrupters then
        table.insert(interrupters, fn)
    else
        handler_interrupters[plugin_name] = { fn }
    end
end

local colorscheme_handler ---@module "prefyl.runtime.handler.colorscheme"
---@param plugin_name string
---@param colorscheme string
function M.handle_colorscheme(plugin_name, colorscheme)
    if colorscheme_handler == nil then
        colorscheme_handler = require("prefyl.runtime.handler.colorscheme")
    end
    return insert_handler_interrupter(
        plugin_name,
        colorscheme_handler(get_plugin_loader(plugin_name), colorscheme)
    )
end

local user_command_handler ---@module "prefyl.runtime.handler.cmd"
---@param plugin_name string
---@param user_command string
function M.handle_user_command(plugin_name, user_command)
    if user_command_handler == nil then
        user_command_handler = require("prefyl.runtime.handler.cmd")
    end
    return insert_handler_interrupter(
        plugin_name,
        user_command_handler(get_plugin_loader(plugin_name), user_command)
    )
end

local event_handler ---@module "prefyl.runtime.handler.event"
---@param plugin_name string
---@param event string | string[]
---@param pattern (string | string[])?
function M.handle_event(plugin_name, event, pattern)
    if event_handler == nil then
        event_handler = require("prefyl.runtime.handler.event")
    end
    return insert_handler_interrupter(
        plugin_name,
        event_handler(get_plugin_loader(plugin_name), event, pattern)
    )
end

---@param path string
---@param callback fun(data: string)
local function read(path, callback)
    vim.uv.fs_open(path, "r", 292, function(e, fd) -- 0o444
        assert(fd, e)
        vim.uv.fs_fstat(fd, function(e, stat)
            assert(stat, e)
            vim.uv.fs_read(fd, stat.size, 0, function(e, data)
                assert(data, e)
                vim.uv.fs_close(fd, function(e, success)
                    assert(success, e)
                end)
                return callback(data)
            end)
        end)
    end)
end

---@param path string
---@return string
local function read_sync(path)
    local fd = assert(vim.uv.fs_open(path, "r", 292)) -- 0o444
    local stat = assert(vim.uv.fs_fstat(fd))
    local data = assert(vim.uv.fs_read(fd, stat.size))
    vim.uv.fs_close(fd, function(e, success)
        assert(success, e)
    end)
    return data
end

---@type table<string, string>
local file_contents = {}

---@param path string
function M.prefetch_file(path)
    return read(path, function(data)
        file_contents[path] = data
    end)
end

---@param s string
---@param path string
---@return function
local function load_str(s, path)
    return assert(loadstring(s, ("@%s"):format(path)))
end

---@param path string
function M.do_file(path)
    local s = file_contents[path]
    if s then
        return load_str(s, path)()
    else
        return read(path, function(s)
            return vim.schedule(load_str(s, path))
        end)
    end
end

---@param path string
function M.do_file_sync(path)
    load_str(file_contents[path] or read_sync(path), path)()
end

return M
