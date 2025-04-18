local Path = require("prefyl.lib.Path")
local async = require("prefyl.lib.async")
local test = require("prefyl.lib.test")

local Chunk = require("prefyl.build.Chunk")

local M = {}

---@return prefyl.async.Future<prefyl.Path[]>
function M.default_runtimepaths()
    async.vim.ensure_scheduled()
    local ps = {
        Path.new(vim.env.VIMRUNTIME),
        Path.new(vim.env.VIM) / ".." / ".." / "lib" / "nvim",
        Path.prefyl_root,
    }
    ---@param path prefyl.Path?
    local function push(path)
        if path then
            table.insert(ps, 1, path)
            table.insert(ps, path / "after")
        end
    end
    push(Path.stdpath.data_dirs[2] and (Path.stdpath.data_dirs[2] / "site"))
    push(Path.stdpath.data_dirs[1] and (Path.stdpath.data_dirs[1] / "site"))
    push(Path.stdpath.data / "site")
    push(Path.stdpath.config_dirs[2])
    push(Path.stdpath.config_dirs[1])
    push(Path.stdpath.config)
    return async.join_list(vim.iter(ps)
        :map(function(path) ---@param path prefyl.Path
            return async.run(function()
                return path:exists().await() and path or nil
            end)
        end)
        :totable())
end

test.test("default_runtimepaths", function()
    async.block_on(M.default_runtimepaths())
end)

---@return prefyl.Path[]
function M.default_packpaths()
    async.vim.ensure_scheduled()
    return { Path.new(vim.env.VIMRUNTIME) }
end

---@nodiscard
---@param path prefyl.Path
---@return prefyl.async.Future<prefyl.build.Chunk>
function M.source(path)
    return async.run(function()
        if path:exists().await() then
            return Chunk.new(
                ('vim.api.nvim_cmd({ cmd = "source", args = { %q } }, {})\n'):format(path)
            )
        else
            return Chunk.new("")
        end
    end)
end

---@nodiscard
---@param group string
---@param body prefyl.build.Chunk[]
---@return prefyl.build.Chunk.Scope
function M.augroup(group, body)
    if 0 < #body then
        return Chunk.scope(vim.iter(body):totable())
            :insert(1, ('vim.api.nvim_cmd({ cmd = "augroup", args = { %q } }, {})\n'):format(group))
            :push('vim.api.nvim_cmd({ cmd = "augroup", args = { "END" } }, {})\n')
    else
        return Chunk.scope()
    end
end

---@nodiscard
---@param paths prefyl.Path[]
function M.set_rtp(paths)
    return Chunk.new(
        ('vim.api.nvim_set_option_value("runtimepath", %q, {})\n'):format(
            vim.iter(paths):map(tostring):join(",")
        )
    )
end

---@nodiscard
---@param paths prefyl.Path[]
---@return prefyl.build.Chunk
function M.add_to_rtp(paths)
    local noafter = ""
    local after = ""
    for _, path in ipairs(paths) do
        if path:ends_with("after") then
            after = after .. "," .. path:tostring()
        else
            noafter = noafter .. path:tostring() .. ","
        end
    end
    if noafter == "" and after == "" then
        return Chunk.new("")
    end
    local s = ""
    if noafter ~= "" then
        s = s .. ("%q .. "):format(noafter)
    end
    s = s .. 'vim.api.nvim_get_option_value("runtimepath", {})'
    if after ~= "" then
        s = s .. (" .. %q"):format(after)
    end
    return Chunk.new(('vim.api.nvim_set_option_value("runtimepath", %s, {})\n'):format(s))
end

test.test("add_to_rtp", function()
    local rtp = 'vim.api.nvim_get_option_value("runtimepath", {})'
    local result = ('vim.api.nvim_set_option_value("runtimepath", "/a/b,/c/d," .. %s .. ",/a/b/after,/c/d/after", {})\n')
        :format(rtp)
        :gsub([[/]], Path.separator() == [[\]] and [[\\]] or [[/]])
    test.assert_eq(
        Chunk.new(result),
        M.add_to_rtp({
            Path.new("/a/b"),
            Path.new("/a/b/after"),
            Path.new("/c/d"),
            Path.new("/c/d/after"),
        })
    )
end)

return M
