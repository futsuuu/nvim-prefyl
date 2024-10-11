local M = {}

---@param list table
---@return uinteger
function M.len(list)
    return (getmetatable(list) or {}).len or #list
end

---@param ... any
---@return any[]
function M.pack(...)
    return setmetatable({ ... }, {
        len = select("#", ...),
        __newindex = function(t, i, v)
            rawset(t, i, v)
            if type(i) == "number" and i < getmetatable(t).len then
                getmetatable(t).len = i
            end
        end,
    })
end

---@param t any[]
---@param i uinteger?
---@param j uinteger?
---@return any ...
function M.unpack(t, i, j)
    return unpack(t, i, j or M.len(t))
end

return M
