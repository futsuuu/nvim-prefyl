local chunk, _ = loadfile(vim.fn.stdpath("state") .. "/prefyl/startup")
if chunk then
    chunk()
else
    -- local repo_dir = vim.fn.stdpath("data") .. "/prefyl/plugins/prefyl"
    local repo_dir = vim.uv.os_homedir() .. "/dev/github.com/futsuuu/nvim-prefyl"
    if not vim.uv.fs_stat(repo_dir) then
        vim.fn.system({
            "git",
            "clone",
            "--filter=blob:none",
            "https://github.com/futsuuu/nvim-prefyl.git",
            repo_dir,
        })
    end
    vim.opt.runtimepath:prepend(repo_dir)
    require("prefyl").build({ load = true })
end

vim.cmd.colorscheme("kanagawa")
-- ... your config ...
