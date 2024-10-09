local M = {}

---@param list table
---@return uinteger
function M.len(list)
    return (getmetatable(list) or {}).len or #list
end

---@generic T
---@param ... T
---@return T[]
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

---@generic T
---@param t T[]
---@param i uinteger?
---@param j uinteger?
---@return T ...
function M.unpack(t, i, j)
    return unpack(t, i, j or M.len(t))
end

return M
