local test = require("prefyl.lib.test")

local handler = require("prefyl.handler.cmd")

test.test("load", function()
    local loaded = false
    handler(function()
        loaded = true
    end, "DummyCommand")

    vim.cmd("DummyCommand")
    assert(loaded)
    assert(not vim.api.nvim_get_commands({})["DummyCommand"])
end)

test.test("call created command", function()
    local called = false
    handler(function()
        vim.api.nvim_create_user_command("DummyCommand", function()
            called = true
        end, {})
    end, "DummyCommand")

    vim.cmd("DummyCommand")
    assert(called)
    assert(vim.api.nvim_get_commands({})["DummyCommand"])

    vim.api.nvim_del_user_command("DummyCommand")
end)
