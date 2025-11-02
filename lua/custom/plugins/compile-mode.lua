return {
  'ej-shafran/compile-mode.nvim',
  version = '^5.0.0',
  -- you can just use the latest version:
  -- branch = "latest",
  -- or the most up-to-date updates:
  -- branch = "nightly",
  dependencies = {
    'nvim-lua/plenary.nvim',
    -- if you want to enable coloring of ANSI escape codes in
    -- compilation output, add:
    -- { "m00qek/baleia.nvim", tag = "v1.3.0" },
  },
  keys = {
    { '<leader>cc', '<cmd>Compile<cr>', desc = 'Compile' },
    { '<leader>cr', '<cmd>Recompile<cr>', desc = 'Recompile' },
    { '<leader>cn', '<cmd>NextError<cr>', desc = 'Next Error' },
    { '<leader>cp', '<cmd>PrevError<cr>', desc = 'Previous Error' },
    { '<leader>ce', '<cmd>CurrentError<cr>', desc = 'Current Error' },
    { '<leader>cf', '<cmd>FirstError<cr>', desc = 'First Error' },
    { '<leader>cQ', '<cmd>QuickfixErrors<cr>', desc = 'Send to Quickfix' },
    { '<leader>cF', '<cmd>NextErrorFollow<cr>', desc = 'Next Error Follow' },
    {
      '<leader>cq',
      function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype == 'compilation' then
            vim.api.nvim_win_close(win, false)
            break
          end
        end
      end,
      desc = 'Close compilation buffer',
    },
  },
  config = function()
    ---@type CompileModeOpts
    vim.g.compile_mode = {
      -- if you use something like `nvim-cmp` or `blink.cmp` for completion,
      -- set this to fix tab completion in command mode:
      input_word_completion = true,
      -- to add ANSI escape code support, add:
      baleia_setup = true,
      -- to make `:Compile` replace special characters (e.g. `%`) in
      -- the command (and behave more like `:!`), add:
      --bang_expansion = true,
    }
  end,
}
