local ok, telescope = pcall(require, "telescope")
if not ok then
  error "This plugin requires telescope.nvim"
end

local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local conf = require("telescope.config").values
local finders = require "telescope.finders"
local pickers = require "telescope.pickers"
local previewers = require "telescope.previewers"
local putils = require "telescope.previewers.utils"

local ok, Job = pcall(require, "plenary.job")
if not ok then
  error "This plugin requires plenary.nvim"
end

local config = {
  query_command = "dasht-query-line",
  open_command = vim.env.BROWSER,
  preview_command = function(entry)
    return { "elinks", "-dump", entry.value.url }
  end,
  related = {},
}

---Escape all wildcard/special characters in a string
local function escape(term)
  -- stylua: ignore start
  return term:gsub("%%", "\\%%")
             :gsub("_" , "\\_")
             :gsub("+" , "\\+")
             :gsub("%." , "\\.")
  -- stylua: ignore end
end

local function format_lang(ft)
  if ft == "lua" then
    ft = string.gsub(_VERSION, "%s", "_")
  end
  return escape(ft)
end

local function run_query(pattern, opts)
  opts = opts or {}

  local query_command = assert(opts.query_command or config.query_command, "Must pass `query_command`")
  local open_command = opts.open_command or config.open_command
  local preview_command = opts.preview_command or config.preview_command

  if type(query_command) == "string" then
    assert(vim.fn.executable(query_command), "query_command must be executable")
    local temp = query_command
    query_command = function(_)
      return temp
    end
  end

  if type(open_command) == "string" then
    assert(vim.fn.executable(open_command), "open_command must be executable")
    local temp = open_command
    open_command = function(entry)
      Job:new({ command = temp, args = { entry.value.url }, detached = true }):start()
    end
  end

  assert(type(preview_command) == "function", "`preview_command` must be a function")

  local lines = {}
  local args = {}
  pattern = pattern or " " -- N.B. Whitespace is a wildcard
  if pattern then
    args = vim.list_extend(args, { pattern })
    -- N.B. We can only pass a docset if we also pass a pattern
    local lang = format_lang(vim.bo.filetype)
    if lang then
      args = vim.list_extend(args, vim.list_extend({ lang }, config.related[vim.bo.filetype] or {}))
    end
  end

  Job
    :new({
      command = query_command(opts),
      args = args,
      on_stdout = function(_, data, _)
        table.insert(lines, data)
      end,
    })
    :sync()

  local results = {}
  for i = 1, #lines, 4 do
    local name = lines[i]:replace("name = ", "")
    local type = lines[i + 1]:replace("type = ", "")
    local from = lines[i + 2]:replace("from = ", "")
    local url = lines[i + 3]:replace("url = ", "")

    local v = {
      name = name,
      type = type,
      from = from,
      url = url,
    }
    table.insert(results, v)
  end

  local function attach_mappings(bufnr, _)
    -- You could disable the "open" functionality by passing `open_function = false`
    if open_command then
      actions.select_default:replace(function()
        actions.close(bufnr)
        open_command(action_state.get_selected_entry())
      end)
    end
    return true
  end

  pickers.new(opts, {
    prompt_title = "~ docsets ~",
    attach_mappings = attach_mappings,
    finder = finders.new_table {
      results = results,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name,
          ordinal = entry.name,
        }
      end,
    },
    previewer = previewers.new_buffer_previewer {
      get_buffer_by_name = function(_, entry)
        return entry.value.url
      end,
      define_preview = function(self, entry, _)
        local command = preview_command(entry)
        putils.job_maker(command, self.state.bufnr, { value = entry.value, bufname = self.state.bufname, conv = true })
      end,
    },
    sorter = conf.generic_sorter(opts),
  }):find()
end

local function find_word_under_cursor(opts)
  local cword = vim.fn.expand "<cword>"
  run_query(cword, opts)
end

return telescope.register_extension {
  setup = function(opts)
    config = vim.tbl_extend("force", config, opts)
  end,
  exports = {
    find_word_under_cursor = find_word_under_cursor,
    query = run_query,
  },
}
