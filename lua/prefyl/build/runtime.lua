local Chunk = require("prefyl.build.Chunk")

local M = {}

local rt = Chunk.new('local rt = require("prefyl.runtime")\n', { output = "rt" })

---@param plugin_name string
---@return prefyl.build.Chunk
function M.load_plugin(plugin_name)
    return Chunk.new(("load_plugin(%q)\n"):format(plugin_name), {
        inputs = {
            Chunk.new(
                ("local load_plugin = %s.load_plugin\n"):format(rt:get_output()),
                { output = "load_plugin", inputs = { rt } }
            ),
        },
    })
end

---@param plugin_name string
---@return prefyl.build.Chunk
function M.load_after_plugin(plugin_name)
    return Chunk.new(("load_after_plugin(%q)\n"):format(plugin_name), {
        inputs = {
            Chunk.new(
                ("local load_after_plugin = %s.load_after_plugin\n"):format(rt:get_output()),
                { output = "load_after_plugin", inputs = { rt } }
            ),
        },
    })
end

---@param name string
---@param loader prefyl.build.Chunk
---@param after_loader prefyl.build.Chunk
function M.set_plugin_loader(name, loader, after_loader)
    return Chunk.new(("set_plugin_loader(%q, plugin_loader, after_plugin_loader)\n"):format(name), {
        inputs = {
            Chunk.new(
                ("local set_plugin_loader = %s.set_plugin_loader\n"):format(rt:get_output()),
                { output = "set_plugin_loader", inputs = { rt } }
            ),
            Chunk.function_("plugin_loader", {}, function()
                return loader
            end, { fixed = true }),
            Chunk.function_("after_plugin_loader", {}, function()
                return after_loader
            end, { fixed = true }),
        },
    })
end

---@param module_name string
---@param chunk string
---@return prefyl.build.Chunk
function M.set_luachunk(module_name, chunk)
    return Chunk.new(("set_luachunk(%q, %q)\n"):format(module_name, chunk), {
        inputs = {
            Chunk.new(
                ("local set_luachunk = %s.set_luachunk\n"):format(rt:get_output()),
                { output = "set_luachunk", inputs = { rt } }
            ),
        },
    })
end

---@param plugin_name string
---@param module_name string
---@return prefyl.build.Chunk
function M.handle_luamodule(plugin_name, module_name)
    return Chunk.new(("handle_luamodule(%q, %q)\n"):format(plugin_name, module_name), {
        inputs = {
            Chunk.new(
                ("local handle_luamodule = %s.handle_luamodule\n"):format(rt:get_output()),
                { output = "handle_luamodule", inputs = { rt } }
            ),
        },
    })
end

---@param plugin_name string
---@param colorscheme string
---@return prefyl.build.Chunk
function M.handle_colorscheme(plugin_name, colorscheme)
    return Chunk.new(("handle_colorscheme(%q, %q)\n"):format(plugin_name, colorscheme), {
        inputs = {
            Chunk.new(
                ("local handle_colorscheme = %s.handle_colorscheme\n"):format(rt:get_output()),
                { output = "handle_colorscheme", inputs = { rt } }
            ),
        },
    })
end

---@param plugin_name string
---@param user_command string
---@return prefyl.build.Chunk
function M.handle_user_command(plugin_name, user_command)
    return Chunk.new(("handle_user_command(%q, %q)\n"):format(plugin_name, user_command), {
        inputs = {
            Chunk.new(
                ("local handle_user_command = %s.handle_user_command\n"):format(rt:get_output()),
                { output = "handle_user_command", inputs = { rt } }
            ),
        },
    })
end

---@param plugin_name string
---@param event string | string[]
---@param pattern? string | string[]
---@return prefyl.build.Chunk
function M.handle_event(plugin_name, event, pattern)
    local args = vim.inspect(event)
    if pattern then
        args = args .. ", " .. vim.inspect(pattern)
    end
    return Chunk.new(("handle_event(%q, %s)\n"):format(plugin_name, args), {
        inputs = {
            Chunk.new(
                ("local handle_event = %s.handle_event\n"):format(rt:get_output()),
                { output = "handle_event", inputs = { rt } }
            ),
        },
    })
end

---@param path prefyl.Path
---@return prefyl.build.Chunk
function M.prefetch_file(path)
    return Chunk.new(("prefetch_file(%q)\n"):format(path), {
        inputs = {
            Chunk.new(
                ("local prefetch_file = %s.prefetch_file\n"):format(rt:get_output()),
                { output = "prefetch_file", inputs = { rt } }
            ),
        },
    })
end

---@param path prefyl.Path
---@return prefyl.build.Chunk
function M.do_file(path)
    return Chunk.new(("do_file(%q)\n"):format(path), {
        inputs = {
            Chunk.new(
                ("local do_file = %s.do_file\n"):format(rt:get_output()),
                { output = "do_file", inputs = { rt } }
            ),
        },
    })
end

---@param path prefyl.Path
---@return prefyl.build.Chunk
function M.do_file_sync(path)
    return Chunk.new(("do_file_sync(%q)\n"):format(path), {
        inputs = {
            Chunk.new(
                ("local do_file_sync = %s.do_file_sync\n"):format(rt:get_output()),
                { output = "do_file_sync", inputs = { rt } }
            ),
        },
    })
end

return M
