local M = {}

local util = require('chat.util')
local job = require('job')

-- Cache officecli availability check
local officecli_available = nil
local function is_officecli_available()
  if officecli_available == nil then
    -- Install officecli on Windows:
    -- scoop install https://raw.githubusercontent.com/wsdjeg/Main-Plus/refs/heads/main/bucket/officecli.json
    officecli_available = vim.fn.executable('officecli') == 1
  end
  return officecli_available
end

-- Valid view modes for Excel files
local VALID_MODES = {
  text = true,
  annotated = true,
  outline = true,
  stats = true,
  issues = true,
  html = true,
}

---@class ChatToolsOfficeCliAction
---@field command? string officecli command (currently only "view" is supported)
---@field filepath? string Path to the office file (e.g., .xlsx)
---@field mode? string View mode: text|annotated|outline|stats|issues|html (default: text)
---@field start? integer Start row (1-indexed) for pagination
---@field ["end"]? integer End row (1-indexed) for pagination
---@field cols? string Column filter (e.g., "A,B,C")
---@field max_lines? integer Maximum output lines
---@field json? boolean Output as JSON
---@field browser? boolean Open in default browser (html mode only)

---@param action table
---@param ctx ChatToolContext
function M.officecli(action, ctx)
  -- Validate command
  local command = action.command or 'view'
  if command ~= 'view' then
    return {
      error = string.format(
        'unsupported command "%s", currently only "view" is supported.',
        command
      ),
    }
  end

  -- Validate filepath
  local filepath = util.resolve(action.filepath, ctx.cwd)

  if not filepath then
    return {
      error = 'failed to run officecli, filepath is required.',
    }
  elseif type(filepath) ~= 'string' then
    return {
      error = 'the type of filepath is not string.',
    }
  elseif vim.fn.filereadable(filepath) == 0 then
    return {
      error = string.format('filepath(%s) is not readable.', filepath),
    }
  end

  if not util.is_allowed_path(filepath) then
    return {
      error = 'not allowed path',
    }
  end

  if not is_officecli_available() then
    return {
      error = 'officecli is not installed or not in PATH.',
    }
  end

  -- Validate mode
  local mode = action.mode or 'text'
  if not VALID_MODES[mode] then
    return {
      error = string.format(
        'invalid mode "%s", expected one of: text, annotated, outline, stats, issues, html.',
        mode
      ),
    }
  end

  -- Build officecli command:  officecli view <filepath> <mode> [options]
  local cmd = { 'officecli', 'view', filepath, mode }

  -- Pagination options
  if action.start ~= nil then
    table.insert(cmd, '--start')
    table.insert(cmd, tostring(action.start))
  end

  if action['end'] ~= nil then
    table.insert(cmd, '--end')
    table.insert(cmd, tostring(action['end']))
  end

  -- Column filter
  if action.cols and type(action.cols) == 'string' and #action.cols > 0 then
    table.insert(cmd, '--cols')
    table.insert(cmd, action.cols)
  end

  -- Limit output
  if action.max_lines ~= nil then
    table.insert(cmd, '--max-lines')
    table.insert(cmd, tostring(action.max_lines))
  end

  -- JSON output
  if action.json == true then
    table.insert(cmd, '--json')
  end

  -- Browser flag (html mode only)
  if action.browser == true then
    if mode ~= 'html' then
      return {
        error = '--browser flag is only valid with mode="html".',
      }
    end
    table.insert(cmd, '--browser')
  end

  local stdout = {}
  local stderr = {}

  local jobid = job.start(cmd, {
    cwd = ctx.cwd,
    on_stdout = function(_, data)
      vim.list_extend(stdout, data)
    end,
    on_stderr = function(_, data)
      vim.list_extend(stderr, data)
    end,
    on_exit = function(id, code, signal)
      if signal ~= 0 then
        ctx.callback({
          error = string.format('officecli cancelled (signal: %d)', signal),
          jobid = id,
        })
        return
      end

      local output = table.concat(stdout, '\n')
      local error_output = table.concat(stderr, '\n')

      -- Combine output
      local full_output = output
      if #error_output > 0 then
        full_output = full_output .. '\n' .. error_output
      end

      local summary = string.format(
        'officecli %s %s %s (exit code: %d)\n\n',
        command,
        mode,
        code == 0 and '✓ Success' or '✗ Failed',
        code
      )

      ctx.callback({
        content = summary .. (full_output ~= '' and full_output or 'No output.'),
        exit_code = code,
        jobid = id,
      })
    end,
  })

  if jobid > 0 then
    return { jobid = jobid }
  end

  return {
    error = 'failed to start officecli job.',
  }
end

function M.scheme()
  return {
    type = 'function',
    ['function'] = {
      name = 'officecli',
      description = [[
Run officecli to view office documents (currently supports Excel .xlsx).

VIEW MODES:
- text:      Plain text dump, tab-separated cell values per row
- annotated: Each cell with reference, value, type/formula, and warnings
- outline:   Structural overview (sheets, rows, cols, formula counts)
- stats:     Summary statistics across all sheets
- issues:    Detect formula errors (#REF!, #VALUE!, #NAME?, #DIV/0!)
- html:      Render as interactive HTML

USAGE:
- @officecli command="view" filepath="data.xlsx"                                    # default text mode
- @officecli command="view" filepath="data.xlsx" mode="text"                        # plain text
- @officecli command="view" filepath="data.xlsx" mode="text" start=1 end=50         # pagination
- @officecli command="view" filepath="data.xlsx" mode="text" cols="A,B,C"           # column filter
- @officecli command="view" filepath="data.xlsx" mode="text" max_lines=100          # limit lines
- @officecli command="view" filepath="data.xlsx" mode="annotated"                   # show formulas/types
- @officecli command="view" filepath="data.xlsx" mode="outline"                     # structure overview
- @officecli command="view" filepath="data.xlsx" mode="stats"                       # statistics
- @officecli command="view" filepath="data.xlsx" mode="issues"                      # quality check
- @officecli command="view" filepath="data.xlsx" mode="html" browser=true           # open in browser
- @officecli command="view" filepath="data.xlsx" mode="text" json=true              # JSON output
]],
      parameters = {
        type = 'object',
        properties = {
          command = {
            type = 'string',
            description = 'officecli command to run (currently only "view" is supported)',
            enum = { 'view' },
          },
          filepath = {
            type = 'string',
            description = 'path to the office file (e.g., users.xlsx)',
          },
          mode = {
            type = 'string',
            description = 'view mode (default: text)',
            enum = { 'text', 'annotated', 'outline', 'stats', 'issues', 'html' },
          },
          start = {
            type = 'integer',
            description = 'start row for pagination (1-indexed, inclusive)',
            minimum = 1,
          },
          ['end'] = {
            type = 'integer',
            description = 'end row for pagination (1-indexed, inclusive)',
            minimum = 1,
          },
          cols = {
            type = 'string',
            description = 'column filter, comma-separated (e.g., "A,B,C")',
          },
          max_lines = {
            type = 'integer',
            description = 'maximum number of output lines',
            minimum = 1,
          },
          json = {
            type = 'boolean',
            description = 'output as JSON',
          },
          browser = {
            type = 'boolean',
            description = 'open in default browser (only valid with mode="html")',
          },
        },
        required = { 'filepath' },
      },
    },
  }
end

function M.info(action, ctx)
  local ok, args = pcall(vim.json.decode, action)
  if not ok then
    return 'officecli'
  end

  local parts = { 'officecli' }
  table.insert(parts, args.command or 'view')

  local filepath = util.resolve(args.filepath, ctx.cwd)
  if filepath then
    table.insert(parts, string.format('filepath=%s', filepath))
  end

  if args.mode then
    table.insert(parts, string.format('mode=%s', args.mode))
  end

  if args.start ~= nil then
    table.insert(parts, string.format('start=%s', args.start))
  end

  if args['end'] ~= nil then
    table.insert(parts, string.format('end=%s', args['end']))
  end

  if args.cols then
    table.insert(parts, string.format('cols=%s', args.cols))
  end

  if args.max_lines ~= nil then
    table.insert(parts, string.format('max_lines=%s', args.max_lines))
  end

  if args.json then
    table.insert(parts, 'json=true')
  end

  if args.browser then
    table.insert(parts, 'browser=true')
  end

  return table.concat(parts, ' ')
end

return M

