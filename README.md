# nvim-prefyl

nvim-prefyl is a super-fast plugin manager for Neovim that focuses on reducing file I/O during Neovim startup and plugin loading.

## Features

- Minimal overhead
- Improved `require()` performance (faster than using `vim.loader`)
- Correct dependency handling

## Requirements

- Neovim stable+ (needs to be built with LuaJIT)
- Git

## Startup script

A script located at `stdpath("state")/prefyl/startup` contains all the processes that nvim-prefyl does at Neovim startup.
You need to run it at the top of your `init.lua`, or call `prefyl.build()` to generate it if it doesn't exist.

The following is a minimal `init.lua`:

```lua
local chunk = loadfile(vim.fn.stdpath("state") .. "/prefyl/startup")
if chunk then
    chunk()
else
    vim.opt.runtimepath:prepend("/path/to/prefyl")
    require("prefyl").build({ run = true })
end
```

### Debugging

By default, `prefyl.build()` generates a binary chunk that is stripped of debug information for better performance.
You can use `debug` option to generate human-readable Lua code (including debug information, of course).

```lua
require("prefyl").build({ debug = true })
```

## Build configuration

// TODO

## Runtime configuration

// TODO

## Development

### Setting up Lua Language Server

```bash
./tools/gen_luarc.lua
```

### Running tests

```bash
./lua/prefyl/lib/test.lua
```

## License

This repository is licensed under the [MIT license](./LICENSE).
