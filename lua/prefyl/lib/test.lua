-- NOTE: don't use other modules in this file.

local M = {}
local running = false

---@class prefyl.test.TestOpts
---@field fail boolean?
---@field defer boolean?
local default_test_opts = {
    fail = false,
    defer = true,
}

---@class prefyl.test.GroupOpts
---@field defer boolean?
local default_group_opts = {
    defer = true,
}

local name_stack = {} ---@type string[]
local deferred_funcs = {} ---@type function[]

---@return boolean
local function is_called()
    return running
        and (
            name_stack[1] == nil
            or name_stack[1] == debug.getinfo(3, "S").source:gsub("^@", ""):gsub("\\", "/")
        )
end

---@overload fun(name: string, func: function)
---@overload fun(name: string, opts: prefyl.test.TestOpts, func: function)
function M.test(name, opts, func)
    if not is_called() then
        return
    end
    if not func then
        func = opts
        opts = {}
    end
    ---@cast opts prefyl.test.TestOpts
    ---@cast func function
    opts = vim.tbl_extend("keep", opts, default_test_opts) ---@type prefyl.test.TestOpts

    local function test()
        table.insert(name_stack, name)
        local success, err = pcall(func)
        local title = table.concat(name_stack, " :: ")
        if (success and not opts.fail) or (not success and opts.fail) then
            print(title .. ": ok")
        elseif success then
            error(title .. ": didn't fail")
        else
            error(title .. ": " .. err)
        end
        table.remove(name_stack)
    end

    if opts.defer then
        table.insert(deferred_funcs, test)
    else
        test()
    end
end

---@overload fun(name: string, func: function)
---@overload fun(name: string, opts: prefyl.test.GroupOpts, func: function)
function M.group(name, opts, func)
    if not is_called() then
        return
    end
    if not func then
        func = opts
        opts = {}
    end
    ---@cast opts prefyl.test.GroupOpts
    ---@cast func function
    opts = vim.tbl_extend("keep", opts, default_group_opts) ---@type prefyl.test.GroupOpts

    local function group()
        table.insert(name_stack, name)
        local deferred_len = #deferred_funcs
        func()
        for _, fn in ipairs(vim.list_slice(deferred_funcs, deferred_len + 1, #deferred_funcs + 1)) do
            fn()
        end
        table.remove(name_stack)
    end

    if opts.defer then
        table.insert(deferred_funcs, group)
    else
        group()
    end
end

---@param obj any
---@return string
local function display(obj)
    if (getmetatable(obj) or {}).__tostring then
        return tostring(obj)
    end
    return vim.inspect(obj)
end

---@param left any
---@param right any
function M.assert_eq(left, right)
    if not is_called() then
        return
    end
    assert(
        vim.deep_equal(left, right),
        "assertion failed:\n left: " .. display(left) .. "\nright: " .. display(right)
    )
end

if arg[0] and arg[0]:gsub("\\", "/"):find("lua/prefyl/lib/test.lua", nil, true) then
    package.loaded["prefyl.lib.test"] = M
    vim.opt.runtimepath:prepend(".")
    running = true

    local lua_files = vim.fs.find(function(name, _path)
        return name:find("%.lua$") ~= nil and name ~= "test.lua"
    end, { limit = math.huge, type = "file", path = "lua" })

    for _, lua_file in ipairs(lua_files) do
        M.group(lua_file, { defer = false }, function()
            dofile(lua_file)
        end)
    end

    vim.cmd("quitall!")
end

return M
