-- Code navigation without LSP: ctags for definitions, ripgrep for references,
-- treesitter for file symbols, keywordprg (man/pydoc/help) for docs.

local TAGS_TIMEOUT_MS = 30000
local HOVER_LINES_MAX = 15

-- Search ./tags in the file's dir and upward, then tags in cwd.
vim.opt.tags = { './tags;', 'tags' }

local tags_job_running = false

local function project_root(bufnr)
  assert(type(bufnr) == 'number')
  local result = vim.fs.root(bufnr, '.git')
  if result == nil then
    result = vim.fn.getcwd()
  end
  assert(type(result) == 'string' and result ~= '')
  return result
end

-- Writes <root>/tags. In git repos only tracked files are indexed (honours .gitignore).
-- --fields=+n adds a line: field so hover can read the definition without a search.
local function tags_generate(root, notify_done)
  assert(type(root) == 'string' and root ~= '')
  if tags_job_running then
    if notify_done then
      vim.notify('ctags already running', vim.log.levels.WARN)
    end
  else
    tags_job_running = true
    local cmd = { 'ctags', '-R', '--fields=+n', '-f', 'tags', '.' }
    if vim.uv.fs_stat(root .. '/.git') then
      cmd = { 'sh', '-c', 'git ls-files | ctags --fields=+n -f tags -L -' }
    end
    vim.system(cmd, { cwd = root, timeout = TAGS_TIMEOUT_MS }, function(out)
      tags_job_running = false
      vim.schedule(function()
        if out.code ~= 0 then
          vim.notify('ctags failed (' .. out.code .. '): ' .. (out.stderr or ''), vim.log.levels.ERROR)
        elseif notify_done then
          vim.notify('tags written: ' .. root .. '/tags')
        end
      end)
    end)
  end
end

vim.api.nvim_create_user_command('MakeTags', function()
  tags_generate(project_root(0), true)
end, { desc = 'Generate ctags for the project root' })

-- Refresh only projects that opted in by having a tags file.
vim.api.nvim_create_autocmd('BufWritePost', {
  group = vim.api.nvim_create_augroup('deeman-tags', { clear = true }),
  callback = function(args)
    local root = project_root(args.buf)
    if vim.uv.fs_stat(root .. '/tags') then
      tags_generate(root, false)
    end
  end,
})

-- Returns up to HOVER_LINES_MAX lines starting at the tag's definition, or {} if unreadable.
local function tag_definition_lines(tag)
  assert(type(tag) == 'table')
  local result = {}
  local line = tonumber(tag.line)
  if line ~= nil and vim.fn.filereadable(tag.filename) == 1 then
    local file_lines = vim.fn.readfile(tag.filename, '', line + HOVER_LINES_MAX - 1)
    result = vim.list_slice(file_lines, line, line + HOVER_LINES_MAX - 1)
  end
  assert(#result <= HOVER_LINES_MAX)
  return result
end

local function docs_lookup(word)
  assert(type(word) == 'string' and word ~= '')
  local ft = vim.bo.filetype
  if ft == 'c' or ft == 'cpp' then
    -- Section 3 first so printf opens the libc page, not printf(1).
    local found = pcall(vim.cmd.Man, '3 ' .. word)
    if not found then
      pcall(vim.cmd.Man, word)
    end
  else
    vim.cmd 'normal! K'
  end
end

-- Project symbol → float with its definition; anything else → man/pydoc/help.
local function hover()
  local word = vim.fn.expand '<cword>'
  if word ~= '' then
    local tags = vim.fn.taglist('^' .. vim.fn.escape(word, '\\^$.*[]~') .. '$')
    local lines = {}
    if #tags > 0 then
      lines = tag_definition_lines(tags[1])
    end
    if #lines > 0 then
      local title = vim.fn.fnamemodify(tags[1].filename, ':~:.') .. ':' .. tags[1].line
      if #tags > 1 then
        title = title .. '  (' .. #tags .. ' matches, grd to pick)'
      end
      vim.lsp.util.open_floating_preview(lines, vim.bo.filetype, { border = 'rounded', title = title, focus_id = 'deeman-hover' })
    else
      docs_lookup(word)
    end
  end
end

local function references()
  require('telescope.builtin').grep_string { word_match = '-w', cwd = project_root(0) }
end

local function rename_in_buffer()
  local word = vim.fn.expand '<cword>'
  local keys = ':%s/\\<' .. word .. '\\>//gc' .. vim.keycode '<Left><Left><Left>'
  vim.api.nvim_feedkeys(keys, 'n', false)
end

-- Neovim's default LSP maps fail with "no client" when no server is attached.
for _, lhs in ipairs { 'grn', 'grr', 'gri', 'grt', 'grx', 'gO' } do
  pcall(vim.keymap.del, 'n', lhs)
end
pcall(vim.keymap.del, { 'n', 'x' }, 'gra')
pcall(vim.keymap.del, { 'i', 's' }, '<C-S>')

local map = vim.keymap.set
map('n', 'grd', 'g<C-]>', { desc = 'Goto definition (tags)' })
map('n', '<C-]>', 'g<C-]>', { desc = 'Goto definition (tags, list if several)' })
map('n', 'grr', references, { desc = 'References (ripgrep, whole word)' })
map('n', 'grn', rename_in_buffer, { desc = 'Rename in buffer (:s with confirm)' })
map('n', 'gO', function()
  require('telescope.builtin').treesitter()
end, { desc = 'File symbols (treesitter)' })
map('n', 'gW', function()
  require('telescope.builtin').tags()
end, { desc = 'Project symbols (tags)' })
map('n', 'K', hover, { desc = 'Hover: tag definition, else man/pydoc/help' })
