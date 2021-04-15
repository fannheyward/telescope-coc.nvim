local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local conf = require('telescope.config').values
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')
local utils = require('telescope.utils')
local async = require('plenary.async_lib').async
local string = string
---@diagnostic disable-next-line: undefined-global
local vim = vim

---@diagnostic disable-next-line: unused-local, unused-function
local function logger(val)
  print(vim.inspect(val))
end

local function is_ready(feature)
  local is_running = vim.call('coc#client#is_running', 'coc')
  if is_running ~= 1 then
    return false
  end
  local ready = vim.call('coc#rpc#ready')
  if ready ~= 1 then
    return false
  end

  local ok = true
  if feature then
    ok = vim.call('CocHasProvider', feature)
    if not ok then
      print("Coc: server does not support " .. feature)
    end
  end
  return ok
end

local locations_to_items = function(locations)
  local items = {}
  for _, r in ipairs(locations) do
    local bufnr = vim.uri_to_bufnr(r.uri)
    vim.fn.bufload(bufnr)
    local filename = vim.uri_to_fname(r.uri)
    local row = r.range.start.line
    local line = (vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false) or {""})[1]
    items[#items+1] = {
      filename = filename,
      lnum = row + 1,
      col = r.range.start.character + 1,
      text = line,
    }
  end

  return items
end

local links = function(opts)
  if not is_ready('documentLink') then
    return
  end

  local results = vim.call('CocAction', 'links')
  if type(results) ~= 'table' or vim.tbl_isempty(results) then
    return
  end

  local locations = {}
  for _, l in ipairs(results) do
    locations[#locations+1] = {
      lnum = l.range.start.line + 1,
      col = l.range.start.character,
      text = l.target
    }
  end

  pickers.new(opts, {
    prompt_title = 'Coc Document Links',
    sorter = conf.generic_sorter(opts),
    finder = finders.new_table {
      results = locations,
      entry_maker = opts.entry_maker or make_entry.gen_from_quickfix(opts),
    },
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        -- TODO, don't work
        local text = action_state.get_selected_entry().value.text
        if text:find('https?://') then
          vim.call('coc#util#open_url', text)
        end
      end)

      return true
    end,
  }):find()
end

local code_actions = function(opts, mode)
  if not is_ready('codeAction') then
    return
  end

  local results = vim.call('CocAction', 'codeActions', mode)
  if type(results) ~= 'table' or vim.tbl_isempty(results) then
    return
  end

  for i, x in ipairs(results) do
    x.idx = i
  end

  pickers.new(opts, {
    prompt_title = 'Coc Code Actions',
    sorter = conf.generic_sorter(opts),
    finder = finders.new_table {
      results = results,
      entry_maker = function(line)
        return {
          valid = line ~= nil,
          value = line,
          ordinal = line.idx .. line.title,
          display = line.idx .. ': ' .. line.title
        }
      end
    },
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        vim.call('CocAction', 'doCodeAction', selection.value)
      end)

      return true
    end,
  }):find()
end

-- TODO
-- range code action
local cursor_code_actions = function(opts)
  code_actions(opts, 'cursor')
end

local line_code_actions = function(opts)
  code_actions(opts, 'line')
end

local file_code_actions = function(opts)
  code_actions(opts, nil)
end

local definitions = function(opts)
  if not is_ready('definition') then
    return
  end

  local defs = vim.call('CocAction', 'definitions')
  if type(defs) ~= 'table' or vim.tbl_isempty(defs) then
    return
  end

  if #defs == 1 then
    vim.lsp.util.jump_to_location(defs[1])
  else
    local locations = locations_to_items(defs)
    pickers.new(opts, {
      prompt_title = 'Coc Definitions',
      previewer = conf.qflist_previewer(opts),
      sorter = conf.generic_sorter(opts),
      finder = finders.new_table {
        results = locations,
        entry_maker = opts.entry_maker or make_entry.gen_from_quickfix(opts),
      },
    }):find()
  end
end

local references = function(opts)
  if not is_ready('reference') then
    return
  end

  local refs = vim.call('CocAction', 'references')
  if type(refs) ~= 'table' or vim.tbl_isempty(refs) then
    return
  end

  local locations = locations_to_items(refs)
  pickers.new(opts, {
    prompt_title = 'Coc References',
    previewer = conf.qflist_previewer(opts),
    sorter = conf.generic_sorter(opts),
    finder    = finders.new_table {
      results = locations,
      entry_maker = opts.entry_maker or make_entry.gen_from_quickfix(opts),
    },
  }):find()
end

local document_symbols = function(opts)
  if not is_ready('documentSymbol') then
    return
  end

  local current_buf = vim.api.nvim_get_current_buf()
  local symbols = vim.call('CocAction', 'documentSymbols', current_buf)
  if type(symbols) ~= 'table' or vim.tbl_isempty(symbols) then
    return
  end

  local locations = {}
  for _, s in ipairs(symbols) do
    locations[#locations+1] = {
      filename = vim.api.nvim_buf_get_name(current_buf),
      lnum = s.lnum,
      col = s.col,
      kind = s.kind,
      text = string.format('[%s] %s', s.kind, s.text),
    }
  end

  opts.ignore_filename = opts.ignore_filename or true
  pickers.new(opts, {
    prompt_title = 'Coc Document Symbols',
    previewer = conf.qflist_previewer(opts),
    finder    = finders.new_table {
      results = locations,
      entry_maker = opts.entry_maker or make_entry.gen_from_lsp_symbols(opts)
    },
    sorter = conf.prefilter_sorter{
      tag = "symbol_type",
      sorter = conf.generic_sorter(opts)
    }
  }):find()
end

local function get_workspace_symbols_requester()
  return async(function(prompt)
    local locations = {}
    local symbols = vim.call('CocAction', 'getWorkspaceSymbols', prompt)
    if type(symbols) ~= 'table' or vim.tbl_isempty(symbols) then
      return locations
    end
    for _, s in ipairs(symbols) do
      local filename = vim.uri_to_fname(s.location.uri)
      local kind = vim.lsp.protocol.SymbolKind[s.kind] or 'Unknown'
      locations[#locations+1] = {
        filename = filename,
        lnum = s.location.range.start.line + 1,
        col = s.location.range.start.character + 1,
        kind = kind,
        text = string.format('[%s] %s', kind, s.name),
      }
    end
    return locations
  end)
end

local workspace_symbols = function(opts)
  pickers.new(opts, {
    prompt_title = 'Coc Workspace Symbols',
    finder    = finders.new_dynamic {
      entry_maker = opts.entry_maker or make_entry.gen_from_lsp_symbols(opts),
      fn = get_workspace_symbols_requester(),
    },
    previewer = conf.qflist_previewer(opts),
    sorter = conf.generic_sorter()
  }):find()
end

local diagnostics = function(opts)
  if not is_ready() then
    return
  end

  local diagnostics = vim.call('CocAction', 'diagnosticList')
  if type(diagnostics) ~= 'table' or vim.tbl_isempty(diagnostics) then
    return
  end

  opts = opts or {}
  local locations = {}
  local buf_names = {}
  local current_buf = vim.api.nvim_get_current_buf()
  local current_filename = vim.api.nvim_buf_get_name(current_buf)
  if opts.get_all then
    local bufs = vim.api.nvim_list_bufs()
    for _,bn in ipairs(bufs) do
      buf_names[vim.api.nvim_buf_get_name(bn)] = bn
    end
  end
  for _, d in ipairs(diagnostics) do
    if opts.get_all or (d.file == current_filename) then
      locations[#locations+1] = {
        bufnr = buf_names[d.file] or current_buf,
        filename = d.file,
        lnum = d.lnum,
        col = d.col,
        start = d.location.range.start,
        finish = d.location.range['end'],
        text = vim.trim(d.message:gsub("[\n]", "")),
        type = d.severity,
      }
    end
  end

  opts.hide_filename = utils.get_default(opts.hide_filename, true)
  pickers.new(opts, {
    prompt_title = 'Coc Diagnostics',
    previewer = conf.qflist_previewer(opts),
    finder = finders.new_table {
      results = locations,
      entry_maker = opts.entry_maker or make_entry.gen_from_lsp_diagnostics(opts)
    },
    sorter = conf.prefilter_sorter{
      tag = "type",
      sorter = conf.generic_sorter(opts)
    }
  }):find()
end

local workspace_diagnostics = function(opts)
  opts = utils.get_default(opts, {})
  opts.hide_filename = utils.get_default(opts.hide_filename, false)
  opts.prompt_title = 'Coc Workspace Diagnostics'
  opts.get_all = true
  diagnostics(opts)
end

local commands = function(opts)
	if not is_ready() then
		return
	end

	local cmds = vim.call("CocAction", "commands")

	if type(cmds) ~= "table" or vim.tbl_isempty(cmds) then
		print("No commands available")
		return
	end

	for _, cmd in ipairs(cmds) do
		if cmd.title == "" then
			cmd.format = cmd.id
		else
			cmd.format = cmd.id .. "\t=> " .. cmd.title
		end
	end

	pickers.new(opts, {
		prompt_title = "Coc Commands",
		sorter = conf.generic_sorter(opts),
		finder = finders.new_table({
			results = cmds,
			entry_maker = function(line)
				return {
					valid = line ~= nil,
					value = line,
					ordinal = line.format,
					display = line.format,
				}
			end,
		}),
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				vim.call("CocActionAsync", "runCommand", selection.value.id)
			end)
			return true
		end,
	}):find()
end

return require('telescope').register_extension{
  exports = {
    links = links,
    -- references = references, -- disabled by now, needs coc update
    -- definitions = definitions,
    diagnostics = diagnostics,
    cursor_code_actions = cursor_code_actions,
    line_code_actions = line_code_actions,
    file_code_actions = file_code_actions,
    document_symbols = document_symbols,
    workspace_symbols = workspace_symbols,
    workspace_diagnostics = workspace_diagnostics,
		commands = commands,
  },
}
