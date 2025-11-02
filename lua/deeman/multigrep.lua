local builtin = require 'telescope.builtin'
local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require 'telescope.config'
local make_entry = require 'telescope.make_entry'

local M = {}

local live_multigrep = function(opts)
  opts = opts or {}
  opts.cwd = opts.cwd or vim.uv.cwd()

  local finder = finders.new_async_job {
    command_generator = function(prompt)
      if not prompt or prompt == '' then
        return nil
      end

      -- Trim whitespace from the prompt
      prompt = vim.trim(prompt)

      -- Split the prompt by two spaces, but only on the first occurrence.
      local pieces = vim.split(prompt, '%s%s', { plain = false, max = 2 })
      local search_term = vim.trim(pieces[1] or '')
      local file_filter = vim.trim(pieces[2] or '')

      if search_term == '' then
        return nil
      end

      local args = { 'rg', '--color=never', '--no-heading', '--with-filename', '--line-number', '--column', '--smart-case' }

      table.insert(args, '-e')
      table.insert(args, search_term)

      if file_filter ~= '' then
        table.insert(args, '-g')
        table.insert(args, file_filter)
      end

      return args
    end,
    entry_maker = make_entry.gen_from_vimgrep(opts),
    cwd = opts.cwd,
  }

  pickers
    .new(opts, {
      debounce = 100,
      prompt_title = 'Multi Grep',
      finder = finder,
      previewer = conf.values.grep_previewer(opts),
      sorter = require('telescope.sorters').empty(),
    })
    :find()
end

M.setup = function()
  vim.keymap.set('n', '<leader>sm', live_multigrep, { desc = '[S]earch by [M]ultigrep. Double Space to enter a filter for filetype' })
end

return M
