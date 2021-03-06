-- lsp dianostic
local vim,api,lsp,util = vim,vim.api,vim.lsp,vim.lsp.util
local window = require 'lspsaga.window'
local libs = require('lspsaga.libs')
local wrap = require 'lspsaga.wrap'
local config = require('lspsaga').config_values
local if_nil = vim.F.if_nil
local M = {}

local function _iter_diagnostic_move_pos(name, opts, pos)
  opts = opts or {}

  local enable_popup = if_nil(opts.enable_popup, true)
  local win_id = opts.win_id or vim.api.nvim_get_current_win()

  if not pos then
    print(string.format("%s: No more valid diagnostics to move to.", name))
    return
  end

  vim.api.nvim_win_set_cursor(win_id, {pos[1] + 1, pos[2]})

  if enable_popup then
    vim.schedule(function()
      M.show_line_diagnostics(opts.popup_opts, vim.api.nvim_win_get_buf(win_id))
    end)
  end
end

function M.lsp_jump_diagnostic_next(opts)
  return _iter_diagnostic_move_pos(
    "DiagnosticNext",
    opts,
    vim.lsp.diagnostic.get_next_pos(opts)
  )
end

function M.lsp_jump_diagnostic_prev(opts)
  return _iter_diagnostic_move_pos(
    "DiagnosticPrevious",
    opts,
    vim.lsp.diagnostic.get_prev_pos(opts)
  )
end

function M.show_line_diagnostics(opts, bufnr, line_nr, client_id)
  local active,msg = libs.check_lsp_active()
  if not active then print(msg) return end
  local max_width = window.get_max_float_width()

  -- if there already has diagnostic float window did not show show lines
  -- diagnostic window
  local has_var, diag_float_winid = pcall(api.nvim_buf_get_var,0,"diagnostic_float_window")
  if has_var and diag_float_winid ~= nil then
    if api.nvim_win_is_valid(diag_float_winid[1]) and api.nvim_win_is_valid(diag_float_winid[2]) then
      return
    end
  end

  opts = opts or {}
  opts.severity_sort = if_nil(opts.severity_sort, true)

  local show_header = if_nil(opts.show_header, true)

  bufnr = bufnr or 0
  line_nr = line_nr or (vim.api.nvim_win_get_cursor(0)[1] - 1)

  local lines = {}
  local highlights = {}
  if show_header then
    lines[1] = config.dianostic_header_icon .. "Diagnostics:"
    highlights[1] =  {0, "LspSagaDiagnosticHeader"}
  end

  local line_diagnostics = lsp.diagnostic.get_line_diagnostics(bufnr, line_nr, opts, client_id)
  if vim.tbl_isempty(line_diagnostics) then return end

  for i, diagnostic in ipairs(line_diagnostics) do
    local prefix = string.format("%d. ", i)
    local hiname = lsp.diagnostic._get_floating_severity_highlight_name(diagnostic.severity)
    assert(hiname, 'unknown severity: ' .. tostring(diagnostic.severity))

    local message_lines = vim.split(diagnostic.message, '\n', true)
    table.insert(lines, prefix..message_lines[1])
    table.insert(highlights, {#prefix + 1, hiname})
    if #message_lines[1] + 4 > max_width then
      table.insert(highlights,{#prefix + 1, hiname})
    end
    for j = 2, #message_lines do
      table.insert(lines, '   '..message_lines[j])
      table.insert(highlights, {0, hiname})
    end
  end
  local border_opts = {
    border = config.border_style,
    highlight = 'LspSagaDiagnosticBorder'
  }

  local wrap_message = wrap.wrap_contents(lines,max_width,{
    fill = true, pad_left = 3
  })
  local truncate_line = wrap.add_truncate_line(lines)
  table.insert(wrap_message,2,truncate_line)

  local content_opts = {
    contents = wrap_message,
    filetype = 'plaintext',
  }

  local cb,cw,bb,bw = window.create_float_window(content_opts,border_opts,opts)
  for i, hi in ipairs(highlights) do
    local _, hiname = unpack(hi)
    -- Start highlight after the prefix
    if i == 1 then
      api.nvim_buf_add_highlight(cb, -1, hiname, 0, 0, -1)
    else
      api.nvim_buf_add_highlight(cb, -1, hiname, i, 3, -1)
    end
  end
  api.nvim_buf_add_highlight(cb,-1,'LspSagaDiagnostcTruncateLine',1,0,-1)
  util.close_preview_autocmd({"CursorMoved", "CursorMovedI", "BufHidden", "BufLeave"}, bw)
  util.close_preview_autocmd({"CursorMoved", "CursorMovedI", "BufHidden", "BufLeave"}, cw)
  api.nvim_win_set_var(0,"show_line_diag_winids",{cw,bw})
  return cb,cw,bb,bw
end

function M.lsp_diagnostic_sign(opts)
  local group = {
    err_group = {
      highlight = 'LspDiagnosticsSignError',
      sign =opts.error_sign
    },
    warn_group = {
      highlight = 'LspDiagnosticsSignWarning',
      sign =opts.warn_sign
    },
    hint_group = {
      highlight = 'LspDiagnosticsSignHint',
      sign =opts.hint_sign
    },
    infor_group = {
      highlight = 'LspDiagnosticsSignInformation',
      sign =opts.infor_sign
    },
  }

  for _,g in pairs(group) do
    vim.fn.sign_define(
    g.highlight,
    {text=g.sign,texthl=g.highlight,linehl='',numhl=''}
    )
  end
end

return M
