Error executing Lua callback: ...are/nvim/lazy/mason.nvim/lua/mason-core/package/init.lua:102: bin: expected table: 0x7ecc62d0b8e8, got table (table: 0x7ecc62c6a320)
stack traceback:
        [C]: in function 'error'
        vim/shared.lua: in function 'validate'
        ...are/nvim/lazy/mason.nvim/lua/mason-core/package/init.lua:102: in function 'validate_spec'
        ...are/nvim/lazy/mason.nvim/lua/mason-core/package/init.lua:116: in function <...are/nvim/lazy/mason.nvim/lua/mason-core/package/init.lua:115>
        vim/shared.lua: in function <vim/shared.lua:0>
        ...m/lazy/mason.nvim/lua/mason-core/functional/function.lua:26: in function <...m/lazy/mason.nvim/lua/mason-core/functional/function.lua:23>
        ...im/lazy/mason.nvim/lua/mason-registry/sources/github.lua:61: in function 'reload'
        ...im/lazy/mason.nvim/lua/mason-registry/sources/github.lua:68: in function 'get_buffer'
        ...im/lazy/mason.nvim/lua/mason-registry/sources/github.lua:74: in function 'get_package'
        ...l/share/nvim/lazy/mason.nvim/lua/mason-registry/init.lua:74: in function <...l/share/nvim/lazy/mason.nvim/lua/mason-registry/init.lua:72>
        vim/shared.lua: in function 'get_all_packages'
        ...cal/share/nvim/lazy/mason.nvim/lua/mason/ui/instance.lua:717: in main chunk
        [C]: in function 'require'
        .../.local/share/nvim/lazy/mason.nvim/lua/mason/ui/init.lua:9: in function 'open'
        ...cal/share/nvim/lazy/mason.nvim/lua/mason/api/command.lua:5: in function <...cal/share/nvim/lazy/mason.nvim/lua/mason/api/command.lua:4>
