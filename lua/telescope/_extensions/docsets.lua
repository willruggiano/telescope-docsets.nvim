local ok, telescope = pcall(require, "telescope")
if not ok then
  error "This plugin requires telescope.nvim"
end

local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
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
}

local function find_word_under_cursor(opts)
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
  local cword = vim.fn.expand "<cword>"

  Job
    :new({
      command = query_command(opts),
      args = {
        cword,
      },
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
  }):find()
end

return telescope.register_extension {
  setup = function(opts)
    config = vim.tbl_extend("force", config, opts)
  end,
  exports = {
    find_word_under_cursor = find_word_under_cursor,
  },
}
