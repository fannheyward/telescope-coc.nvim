local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local themes = require('telescope.themes')
local conf = require('telescope.config').values
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')
local entry_display = require('telescope.pickers.entry_display')
local utils = require('telescope.utils')
local Path = require('plenary.path')
local async = require('plenary.async_lib').async
local string = string
---@diagnostic disable-next-line: undefined-global
local vim = vim
---@diagnostic disable-next-line: undefined-global
local jit = jit

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
  for _, l in ipairs(locations) do
    if l.targetUri and l.targetRange then
      -- LocationLink
      l.uri = l.targetUri
      l.range = l.targetRange
    end
    local bufnr = vim.uri_to_bufnr(l.uri)
    vim.fn.bufload(bufnr)
    local filename = vim.uri_to_fname(l.uri)
    local row = l.range.start.line
    local line = (vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false) or {""})[1]
    items[#items+1] = {
      filename = filename,
      lnum = row + 1,
      col = l.range.start.character + 1,
      text = line,
    }
  end

  return items
end

local mru = function(opts)
  if not is_ready() then
    return
  end

  local home = vim.call('coc#util#get_data_home')
  local data = Path:new(home .. Path.path.sep .. 'mru'):read()
  if not data or #data == 0 then
    return
  end

  local results = {}
  local cwd = vim.loop.cwd() .. Path.path.sep
  for _, val in ipairs(utils.max_split(data, '\n')) do
    local p = Path:new(val)
    local lowerPrefix = val:sub(1, #cwd):gsub(Path.path.sep, ''):lower()
    local lowerCWD = cwd:gsub(Path.path.sep, ''):lower()
    if lowerCWD == lowerPrefix and p:exists() and p:is_file() then
      results[#results+1] = val:sub(#cwd+1)
    end
  end
  pickers.new(opts, {
    prompt_title = 'Coc MRU',
    sorter = conf.generic_sorter(opts),
    previewer = conf.qflist_previewer(opts),
    finder = finders.new_table {
      results = results,
      entry_maker = function(line)
        return {
          valid = line ~= nil,
          value = line,
          ordinal = line,
          display = line,
        }
      end
    },
  }):find()
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
        local text = action_state.get_selected_entry().value.text
        if text:find('https?://') then
          local opener = (jit.os == 'OSX' and 'open') or 'xdg-open'
          os.execute(opener .. ' ' .. text)
        end
      end)

      return true
    end,
  }):find()
end

local handle_code_actions = function(opts, mode)
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

  local center_list = themes.get_dropdown()
  pickers.new(center_list, {
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
  handle_code_actions(opts, 'cursor')
end

local line_code_actions = function(opts)
  handle_code_actions(opts, 'line')
end

local file_code_actions = function(opts)
  handle_code_actions(opts, nil)
end

local function list_or_jump(opts)
  if not is_ready(opts.coc_provider) then
    return
  end

  local defs = vim.call('CocAction', opts.coc_action)
  if type(defs) ~= 'table' or vim.tbl_isempty(defs) then
    return
  end

  if #defs == 1 then
    vim.lsp.util.jump_to_location(defs[1])
  else
    local locations = locations_to_items(defs)
    pickers.new(opts, {
      prompt_title = opts.coc_title,
      previewer = conf.qflist_previewer(opts),
      sorter = conf.generic_sorter(opts),
      finder = finders.new_table {
        results = locations,
        entry_maker = opts.entry_maker or make_entry.gen_from_quickfix(opts),
      },
    }):find()
  end
end

local definitions = function(opts)
  opts.coc_provider = 'definition'
  opts.coc_action = 'definitions'
  opts.coc_title = 'Coc Definitions'
  list_or_jump(opts)
end

local declarations = function(opts)
  opts.coc_provider = 'declaration'
  opts.coc_action = 'declarations'
  opts.coc_title = 'Coc Declarations'
  list_or_jump(opts)
end

local implementations = function(opts)
  opts.coc_provider = 'implementation'
  opts.coc_action = 'implementations'
  opts.coc_title = 'Coc Implementations'
  list_or_jump(opts)
end

local type_definitions = function(opts)
  opts.coc_provider = 'typeDefinition'
  opts.coc_action = 'typeDefinitions'
  opts.coc_title = 'Coc TypeDefinitions'
  list_or_jump(opts)
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

local locations = function(opts)
  local refs = vim.g.coc_jump_locations
  local locations = locations_to_items(refs)
  pickers.new(opts, {
    prompt_title = 'Coc Locations',
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

  opts.path_display = utils.get_default(opts.path_display, "hidden")
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
  opts.path_display = utils.get_default(opts.path_display, "shorten")
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

  local displayer = entry_display.create {
    separator = ' ',
    items = {
      { width = 40 },
      { remaining = true },
    },
  }
  local make_display = function(entry)
    return displayer {
      { entry.value, 'TelescopeResultsFunction' },
      entry.description
    }
  end

  pickers.new(opts, {
    prompt_title = "Coc Commands",
    sorter = conf.generic_sorter(opts),
    finder = finders.new_table({
      results = cmds,
      entry_maker = function(line)
        return {
          value = line.id,
          valid = line.id ~= nil,
          ordinal = line.id,
          display = make_display,
          description = line.title or '',
        }
      end,
    }),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        vim.call("CocActionAsync", "runCommand", selection.value)
      end)
      return true
    end,
  }):find()
end

return require('telescope').register_extension{
  exports = {
    mru = mru,
    links = links,
    commands = commands,
    locations = locations,
    references = references,
    diagnostics = diagnostics,
    definitions = definitions,
    declarations = declarations,
    implementations = implementations,
    type_definitions = type_definitions,
    code_actions = cursor_code_actions,
    line_code_actions = line_code_actions,
    file_code_actions = file_code_actions,
    document_symbols = document_symbols,
    workspace_symbols = workspace_symbols,
    workspace_diagnostics = workspace_diagnostics,
  },
}

-- vim: set sw=2 ts=2 sts=2 et
