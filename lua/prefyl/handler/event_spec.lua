local test = require("prefyl.lib.test")

local handler = require("prefyl.handler.event")

test.test("load", function()
    local loaded = false
    handler(function()
        loaded = true
    end, "User", "prefyl-test")

    vim.api.nvim_exec_autocmds("User", { pattern = "prefyl-test" })
    assert(loaded)
end)

test.test("execute created autocmds", function()
    local group = vim.api.nvim_create_augroup("prefyl_test_loader", {})

    local executed = false
    handler(function()
        vim.api.nvim_create_autocmd("User", {
            pattern = "prefyl-test",
            once = true,
            group = group,
            callback = function(cx)
                executed = true
                test.assert_eq("hello world", cx.data)
            end,
        })
    end, "User", "prefyl-test")

    vim.api.nvim_exec_autocmds("User", { pattern = "prefyl-test", data = "hello world" })
    assert(executed)

    vim.api.nvim_del_augroup_by_id(group)
end)
