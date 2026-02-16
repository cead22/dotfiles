local lspconfig = require('lspconfig')

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
  local params = vim.lsp.util.make_position_params(0, 'utf-8')
  vim.lsp.buf_request_all(bufnr, 'textDocument/definition', params, function(responses)
    local all = {}
    for _, resp in pairs(responses or {}) do
      if resp.result then
        for _, loc in ipairs(locations_to_list(resp.result)) do
          table.insert(all, loc)
        end
      end
    end
    if #all == 0 then return end
    -- Prefer locations in the same git root as current file
    local in_repo, other = {}, {}
    for _, loc in ipairs(all) do
      local fpath = uri_to_path(loc.uri)
      local loc_git = git_root_for_file(fpath)
      if cur_git and loc_git and loc_git == cur_git then
        table.insert(in_repo, loc)
      else
        table.insert(other, loc)
    end
    end
    local chosen = in_repo[1]
    if not chosen and #other > 0 then chosen = other[1] end
    -- Prefer same file if multiple in repo
    if chosen and #in_repo > 1 then
      local cur_norm = (cur_path:gsub('\\', '/'):gsub('^file://', ''))
      for _, loc in ipairs(in_repo) do
        if uri_to_path(loc.uri) == cur_norm then chosen = loc break end
      end
    end
    if chosen then
      vim.lsp.util.show_document(chosen, 'utf-8', { reuse_win = true, focus = true })
    end
  end)
end

-- Shared LSP keymaps (g], gr, K) and CursorHold float for all language servers
local function common_on_attach(client, bufnr)
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
end

-- Configure clangd (Auth repo)
lspconfig.clangd.setup {
  on_attach = function(client, bufnr)
    common_on_attach(client, bufnr)
    vim.keymap.set('n', '<leader>s', ':ClangdSwitchSourceHeader<CR>', { noremap = true, silent = true, buffer = bufnr })
  end,
}

-- Configure intelephense (any PHP repo with composer.json: Web-Expensify, Server-Scraper, etc.)
lspconfig.intelephense.setup {
  on_attach = common_on_attach,
  root_dir = lspconfig.util.root_pattern('composer.json'),
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
}

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
