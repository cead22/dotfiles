local function uri_to_path(uri)
    if not uri or uri == '' then return '' end
    if vim.uri_to_fname then return vim.uri_to_fname(uri) end
    return (uri:gsub('^file://', ''):gsub('%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end))
end

-- Return git root for a file path, or nil
local function git_root_for_file(filepath)
    if not filepath or filepath == '' then return nil end
    local dir = filepath:match('^(.+)/[^/]*$') or filepath
    local out = vim.fn.systemlist({ 'git', '-C', dir, 'rev-parse', '--show-toplevel' })
    if vim.v.shell_error ~= 0 or not out[1] then return nil end
    return out[1]:gsub('\\', '/')
end

-- Normalize LSP definition result to a list of { uri, range }
local function locations_to_list(result)
    if not result then return {} end
    local list = {}
    local function add(uri, range)
        if uri and range then table.insert(list, { uri = uri, range = range }) end
    end
    if result.uri then
        add(result.uri, result.range)
        return list
    end
    if result.targetUri then
        add(result.targetUri, result.targetRange or result.targetSelectionRange)
        return list
    end
    for _, loc in ipairs(result) do
        if loc.uri then add(loc.uri, loc.range)
        elseif loc.targetUri then add(loc.targetUri, loc.targetRange or loc.targetSelectionRange)
        end
    end
    return list
end

-- Go to definition: prefer same repo, jump directly (no picker)
local function goto_definition_same_repo()
    local bufnr = vim.api.nvim_get_current_buf()
    local cur_path = vim.api.nvim_buf_get_name(bufnr)
    local cur_git = git_root_for_file(cur_path)
    local clients = vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/definition' })
    if #clients == 0 then
        vim.notify('LSP: no client attached', vim.log.levels.WARN)
        return
    end
    local encoding = clients[1].offset_encoding or 'utf-8'
    local params = vim.lsp.util.make_position_params(0, encoding)
    vim.lsp.buf_request_all(bufnr, 'textDocument/definition', params, function(responses)
        local all = {}
        for client_id, resp in pairs(responses or {}) do
            if resp.result then
                local client = vim.lsp.get_client_by_id(client_id)
                local enc = client and client.offset_encoding or encoding
                for _, loc in ipairs(locations_to_list(resp.result)) do
                    table.insert(all, { loc = loc, enc = enc })
                end
            end
        end
        if #all == 0 then
            vim.notify('LSP: no definition found', vim.log.levels.INFO)
            return
        end
        -- Prefer locations in the same git root as current file
        local in_repo, other = {}, {}
        for _, item in ipairs(all) do
            local fpath = uri_to_path(item.loc.uri)
            local loc_git = git_root_for_file(fpath)
            if cur_git and loc_git and loc_git == cur_git then
                table.insert(in_repo, item)
            else
                table.insert(other, item)
            end
        end
        -- Prefer .cpp over .h (definition over declaration)
        local function pick_best(items)
            for _, item in ipairs(items) do
                if uri_to_path(item.loc.uri):match('%.cpp$') then return item end
            end
            return items[1]
        end
        local chosen = pick_best(in_repo)
        if not chosen and #other > 0 then chosen = pick_best(other) end
        if chosen then
            local ok, err = pcall(vim.lsp.util.show_document, chosen.loc, chosen.enc, { reuse_win = true, focus = true })
            if not ok then
                vim.notify('LSP: failed to open definition: ' .. tostring(err), vim.log.levels.ERROR)
            end
        end
    end)
end

-- LSP keymaps and CursorHold float for all language servers
vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
        local bufnr = args.buf
        local client = vim.lsp.get_client_by_id(args.data.client_id)

        vim.api.nvim_create_autocmd("CursorHold", {
            buffer = bufnr,
            callback = function()
                vim.diagnostic.open_float(nil, { focus = false })
            end,
        })

        local opts = { noremap = true, silent = true, buffer = bufnr }
        vim.keymap.set('n', 'g]', goto_definition_same_repo, opts)
        vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)

        -- clangd-specific: switch source/header
        if client and client.name == 'clangd' then
            vim.keymap.set('n', '<leader>s', function()
                local params = { uri = vim.uri_from_fname(vim.api.nvim_buf_get_name(bufnr)) }
                client:request('textDocument/switchSourceHeader', params, function(err, result)
                    if result then vim.cmd('edit ' .. vim.uri_to_fname(result)) end
                end)
            end, opts)
        end
    end,
})

-- Configure clangd
vim.lsp.config('clangd', {})

-- Configure intelephense
vim.lsp.config('intelephense', {
    root_markers = { 'composer.json' },
    init_options = {
        files = {
            exclude = {
                '**/node_modules/**',
                '**/.git/**',
                '**/build/**',
                '**/vendor/**/tests/**',
            },
        },
    },
})

-- Enable servers
vim.lsp.enable({ 'clangd', 'intelephense' })

-- Configure diagnostics display
vim.diagnostic.config({
    virtual_text = true,
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
})

local function toggle_command_test()
    local current_file = vim.api.nvim_buf_get_name(0)
    local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]

    -- Normalize slashes just in case
    current_file = current_file:gsub('\\', '/')

    local command_dir = '/auth/command/'
    local test_dir = '/test/test/command/'

    if current_file:find(command_dir) then
        -- You're in a command file, go to the test
        local name = current_file:match('.*/auth/command/(.+)%.cpp$')
        if not name then
            print("Couldn't extract command name.")
            return
        end
        local target = git_root .. test_dir .. name .. 'Test.cpp'
        vim.cmd('edit ' .. target)
    elseif current_file:find(test_dir) then
        -- You're in a test file, go to the command
        local name = current_file:match('.*/test/test/command/(.+)Test%.cpp$')
        if not name then
            print("Couldn't extract test name.")
            return
        end
        local target = git_root .. command_dir .. name .. '.cpp'
        vim.cmd('edit ' .. target)
    else
        print('Not in a command or test file.')
    end
end

vim.keymap.set('n', '<leader>t', toggle_command_test, { noremap = true, silent = true })
