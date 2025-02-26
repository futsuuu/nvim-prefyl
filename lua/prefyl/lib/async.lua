local M = {}
package.loaded[...] = M

local test = require("prefyl.lib.test")

local Future = require("prefyl.lib.async.Future")

M.Future = Future
M.time = require("prefyl.lib.async.time")
M.uv = require("prefyl.lib.async.uv")
M.vim = require("prefyl.lib.async.vim")

local threads = {} ---@type table<thread, true>

---@generic T, U, V, W, X, Y, Z
---@param func fun(): T?, U?, V?, W?, X?, Y?, Z?
---@return prefyl.async.Future<T?, U?, V?, W?, X?, Y?, Z?>
function M.run(func)
    return Future.new(function(finish)
        local co
        co = coroutine.create(function()
            finish(func())
            threads[co] = nil
        end)
        threads[co] = true
        assert(coroutine.resume(co))
    end)
end

---@return thread?
---@return string? err
function M.current_thread()
    local running = coroutine.running()
    if not running then
        return nil, "currently running on the main thread"
    elseif not threads[running] then
        return nil, "currently running on an unknown thread"
    else
        return running
    end
end

---@generic T, U, V, W, X, Y, Z
---@param future prefyl.async.Future<T?, U?, V?, W?, X?, Y?, Z?>
---@return T?, U?, V?, W?, X?, Y?, Z?
function M.block_on(future)
    local finished = false
    M.run(function()
        future.await()
        finished = true
    end)
    vim.wait(2 ^ 20, function()
        return finished
    end)
    return future.await()
end

---@generic T
---@param ... prefyl.async.Future<T>
---@return prefyl.async.Future<T, T, T, T, T, T, T>
function M.join(...)
    return Future.new(function(finish, ...)
        local len = select("#", ...) ---@type integer
        if len == 0 then
            return finish()
        end
        local result = {}
        local done = 0
        for i = 1, len do
            local future = select(i, ...)
            M.run(function()
                result[i] = future.await()
                done = done + 1
                if done == len then
                    return finish(unpack(result, 1, len))
                end
            end)
        end
    end, ...)
end

test.group("join", function()
    test.test("noop", function()
        M.join().await()
    end)

    test.test("join", function()
        test.assert_eq({ 1, nil, 3 }, {
            M.join(
                M.run(function()
                    return 1
                end),
                M.run(function()
                    return nil, 2
                end),
                M.run(function()
                    return 3
                end)
            ).await(),
        })
    end)
end)

---@generic T
---@param futures prefyl.async.Future<T>[]
---@return prefyl.async.Future<T[]>
function M.join_list(futures)
    return Future.new(function(finish)
        local len = #futures
        if len == 0 then
            return finish({})
        end
        local result = {}
        local done = 0
        for _, future in ipairs(futures) do
            M.run(function()
                table.insert(result, (future.await()))
                done = done + 1
                if done == len then
                    return finish(result)
                end
            end)
        end
    end)
end

test.group("join_list", function()
    test.test("noop", function()
        M.join_list({}).await()
    end)

    test.test("join", function()
        test.assert_eq(
            { 1, 3 },
            M.join_list({
                M.run(function()
                    return 1
                end),
                M.run(function()
                    return nil, 2
                end),
                M.run(function()
                    return 3
                end),
            }).await()
        )
    end)
end)

---@generic K, T
---@param futures table<K, prefyl.async.Future<T>>
---@return prefyl.async.Future<table<K, T>>
function M.join_dict(futures)
    return Future.new(function(finish)
        local len = #vim.tbl_keys(futures)
        if len == 0 then
            return finish({})
        end
        local result = {}
        local done = 0
        for key, future in pairs(futures) do
            M.run(function()
                result[key] = future.await()
                done = done + 1
                if done == len then
                    return finish(result)
                end
            end)
        end
    end)
end

test.group("join_dict", function()
    test.test("noop", function()
        M.join_dict({}).await()
    end)

    test.test("join", function()
        test.assert_eq(
            { a = 1, c = 3 },
            M.block_on(M.join_dict({
                a = M.run(function()
                    M.time.sleep(100).await()
                    return 1
                end),
                b = M.run(function()
                    M.time.sleep(200).await()
                    return nil, 2
                end),
                c = M.run(function()
                    M.time.sleep(300).await()
                    return 3
                end),
            }))
        )
    end)
end)

return M
