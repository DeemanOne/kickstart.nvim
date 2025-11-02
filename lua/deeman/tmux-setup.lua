local Job = require 'plenary.job'
local M = {} -- Our module table

-- Immediately exit if not running inside a tmux session.
if not os.getenv 'TMUX' then
  M.dir_change = function()
    print 'Not running inside a tmux session. No action taken.'
  end
  return M
end

local cwd = vim.fn.getcwd()

--- Sends a command string to a specific tmux target (pane).
-- @param target string The target pane ID (e.g., '%1').
-- @param command string The command to execute.
local function send_keys(target, command)
  if not target or not command then
    return
  end
  Job:new({
    'tmux',
    'send-keys',
    '-t',
    target,
    command,
    'Enter',
    cwd = cwd,
  }):sync()
end

--- Changes directory in all panes of the current window, except the active Neovim pane.
-- @param dir string The directory path to change to.
function M.dir_change(dir)
  if not dir then
    return
  end

  local root_dir_job = Job:new({ 'git', 'rev-parse', '--show-toplevel' }, { cwd = dir })
  local root_dir_result = root_dir_job:sync()
  local root_dir = root_dir_result and root_dir_result[1]

  if not root_dir or root_dir == '' then
    vim.notify('Could not find git root for: ' .. dir, vim.log.levels.ERROR)
    return
  end

  -- Get the ID of the current pane (where Neovim is) and its window
  local nvim_pane_id_job = Job:new { 'tmux', 'display-message', '-p', '#{pane_id}' }
  local nvim_pane_id = nvim_pane_id_job:sync()[1]

  local current_window_id_job = Job:new { 'tmux', 'display-message', '-p', '#{window_id}' }
  local current_window_id = current_window_id_job:sync()[1]

  if not nvim_pane_id or not current_window_id then
    vim.notify('Tmux: Could not identify current pane/window.', vim.log.levels.ERROR)
    return
  end

  -- List all panes in the current window, getting their IDs
  local panes_job = Job:new { 'tmux', 'list-panes', '-t', current_window_id, '-F', '#{pane_id}' }
  local all_panes = panes_job:sync()

  if not all_panes then
    return
  end

  local escaped_root = vim.fn.shellescape(root_dir)
  local escaped_new_dir = vim.fn.shellescape(dir)
  local command = string.format('cd %s && cd %s && clear', escaped_root, escaped_new_dir)
  --local command = string.format("cd %s && clear", vim.fn.shellescape(dir))
  local panes_updated = 0

  -- Iterate through all panes and send the command to every pane that IS NOT Neovim's pane
  for _, pane_id in ipairs(all_panes) do
    if pane_id ~= nvim_pane_id then
      send_keys(pane_id, command)
      panes_updated = panes_updated + 1
    end
  end

  if panes_updated > 0 then
    vim.notify(string.format('Tmux: Updated directory in %d other pane(s).', panes_updated))
  end
end
return M
--local Job = require("plenary.job")
--local cwd = vim.fn.getcwd()
--local dirChangeCommand = 'cd'
--local terminalClearCommand = 'clear'
--
--local sessionStatus = os.getenv("TMUX")
--local mysplit = function(inputstr, sep)
--    if sep == nil then
--        sep = "%s"
--    end
--    local t = {}
--    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
--        table.insert(t, str)
--    end
--    return t
--end
--
--local sessionId = mysplit(sessionStatus, ",")[3]
--local termianlWindowId = string.format("%s:%s.%s", sessionId, 2, 1)
--
--local tmuxWindows = Job:new({ 'tmux', 'list-windows', cwd = cwd }):sync()
--
--vim.notify('resut:' .. #tmuxWindows)
--if #tmuxWindows == 1 then
--    Job:new({ 'tmux', 'rename-window', '-t', '1', 'main:NVIM', cwd = cwd }):sync()
--    Job:new({ 'tmux', 'new-window', '-n', 'terminal', cwd = cwd }):sync()
--    Job:new({ 'tmux', 'select-window', '-t', '1', cwd = cwd }):sync()
--end
--
--local sendKeys = function(command)
--    Job:new({ 'tmux', 'send-keys', '-t', termianlWindowId, command, 'Enter', cwd = cwd }):sync()
--end
--
--local clear_terminal = function()
--    local command = string.format("%s", terminalClearCommand)
--    sendKeys(command)
--end
--
--local dir_change_function = function(dir)
--    vim.notify('changing to:' .. dir)
--    local command = string.format("%s %s", dirChangeCommand, dir)
--    sendKeys(command)
--    clear_terminal()
--end
--
--return {
--    dir_change = dir_change_function
--}
