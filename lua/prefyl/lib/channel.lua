local M = {}

local async = require("prefyl.lib.async")
local test = require("prefyl.lib.test")
local Future = async.Future

---@alias prefyl.channel.Sender<T> fun(value: T): boolean, string?
---@alias prefyl.channel.Receiver<T> fun(): prefyl.async.Future<T?, string?>

---@class prefyl.channel.State
---@field is_closed boolean
---@field values { value: any }[]
---@field recv_callbacks fun(value: any, err: string?)[]
---@field close_callbacks fun()[]
local State = {}
---@private
State.__index = State

---@generic T
---@return prefyl.channel.Sender<T>
---@return prefyl.channel.Receiver<T>
function M.new()
    local state = State.new()

    ---@generic T
    ---@type prefyl.channel.Sender<T>
    local function tx(value)
        return state:send(value)
    end

    ---@generic T
    ---@type prefyl.channel.Receiver<T>
    local function rx()
        return Future.new(function(finish)
            state:recv(finish)
        end)
    end

    return state:set(tx), state:set(rx)
end

---@return self
function State.new()
    ---@type prefyl.channel.State
    local self = {
        is_closed = false,
        values = {},
        recv_callbacks = {},
        close_callbacks = {},
    }
    return setmetatable(self, State)
end

---@param value any
---@return boolean
---@return string?
function State:send(value)
    if self.is_closed then
        return false, "channel already closed"
    elseif self.recv_callbacks[1] then
        local callback = table.remove(self.recv_callbacks, 1) ---@type fun(value: any, err: string?)
        callback(value)
    else
        table.insert(self.values, { value = value })
    end
    return true
end

---@param callback fun(value: any, err: string?)
function State:recv(callback)
    if self.values[1] then
        local value = table.remove(self.values, 1) ---@type { value: any }
        callback(value.value)
    elseif self.is_closed then
        callback(nil, "channel already closed")
    else
        table.insert(self.recv_callbacks, callback)
    end
end

test.group("tx rx", function()
    test.test("send and receive", function()
        local tx, rx = M.new()
        assert(tx(1))
        test.assert_eq(1, rx().await())
    end)

    test.test("send while receiving", function()
        async.block_on(async.async(function()
            local tx, rx = M.new()
            local f = async.async(function()
                test.assert_eq(1, rx().await())
            end)
            assert(tx(1))
            f.await()
        end))
    end)

    test.test("send after closed", function()
        local tx, rx = M.new()
        M.close(rx)
        test.assert_eq(false, (tx(1)))
        test.assert_eq(nil, rx().await())
    end)

    test.test("receive after closed", function()
        local tx, rx = M.new()
        assert(tx(1))
        M.close(rx)
        test.assert_eq(1, rx().await())
        test.assert_eq(nil, rx().await())
    end)
end)

local ENV_KEY = newproxy(false)

---@generic F: function
---@param ch F
---@return F
function State:set(ch)
    return setfenv(ch, setmetatable({ [ENV_KEY] = self }, { __index = _G }))
end

---@param ch function
---@return self
function State.get(ch)
    return assert(
        getfenv(ch)[ENV_KEY],
        "channel sender or receiver expected, got unknown " .. type(ch)
    )
end

---@param ch prefyl.channel.Sender<any> | prefyl.channel.Receiver<any>
---@return boolean
function M.is_closed(ch)
    return State.get(ch).is_closed
end

---@param ch prefyl.channel.Sender<any> | prefyl.channel.Receiver<any>
---@return boolean
---@return string? err
function M.close(ch)
    local state = State.get(ch)
    if state.is_closed then
        return false, "channel already closed"
    end
    state.is_closed = true
    for _, callback in ipairs(state.recv_callbacks) do
        callback(nil, "channel closed")
    end
    for _, callback in ipairs(state.close_callbacks) do
        callback()
    end
    return true
end

test.test("close", function()
    local tx, rx = M.new()
    assert(not M.is_closed(tx))
    assert(not M.is_closed(rx))
    M.close(tx)
    assert(M.is_closed(tx))
    assert(M.is_closed(rx))
end)

---@param ch prefyl.channel.Sender<any> | prefyl.channel.Receiver<any>
---@return prefyl.async.Future<nil>
function M.closed(ch)
    local state = State.get(ch)
    return Future.new(function(finish)
        if state.is_closed then
            finish()
        else
            table.insert(state.close_callbacks, finish)
        end
    end)
end

test.test("closed", function()
    local tx, rx = M.new()
    local a = 0
    async.async(function()
        M.closed(tx).await()
        a = a + 1
    end)
    async.async(function()
        M.closed(rx).await()
        a = a + 1
    end)
    test.assert_eq(0, a)
    M.close(rx)
    test.assert_eq(2, a)
end)

---@param ch prefyl.channel.Sender<any> | prefyl.channel.Receiver<any>
---@return integer
function M.len(ch)
    return #State.get(ch).values
end

---@param ch prefyl.channel.Sender<any> | prefyl.channel.Receiver<any>
---@return boolean
function M.is_empty(ch)
    return State.get(ch).values[1] ~= nil
end

return M
