local M = {}

local function get_data_dir()
  return vim.fn.stdpath("state") .. "/term/"
end

-- ======================
-- SAVE TERMINAL OUTPUT
-- ======================
function M.save()
  local buf = vim.api.nvim_get_current_buf()

  if vim.bo.buftype ~= "terminal" then
    vim.notify("Not a terminal buffer", vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  
  if #lines == 0 then
    vim.notify("No terminal content to save", vim.log.levels.WARN)
    return
  end

  local dir = get_data_dir()
  vim.fn.mkdir(dir, "p")

  local id = "term_" .. os.time() .. "_" .. math.random(1000,9999)
  local path = dir .. id .. ".mpack"


  local name = vim.api.nvim_buf_get_name(buf)

  local data = {
    version = 1,
    id = id,
    uri = name,
    cwd = vim.fn.getcwd(),
    cols = vim.api.nvim_win_get_width(0),
    rows = vim.api.nvim_win_get_height(0),
    timestamp = os.time(),
    lines = lines,
  }

  local packed = vim.mpack.encode(data)

  local file = io.open(path, "wb")
  if not file then
    vim.notify("Failed to save", vim.log.levels.ERROR)
    return
  end

  file:write(packed)
  file:close()

  vim.notify("Saved to: " .. path, vim.log.levels.INFO)
end

-- ======================
-- LIST SAVED SESSIONS
-- ======================


function M.list()
  local dir = get_data_dir()
  vim.fn.mkdir(dir, "p")

  local files = vim.fn.readdir(dir)

  local display = {}
  local map = {}

  for _, file in ipairs(files) do
    if not file:match("^term_%d+_%d+%.mpack$") then
      goto continue
    end

    local path = dir .. file

    if vim.fn.filereadable(path) == 1 then
      local f = io.open(path, "rb")
      if f then
        local content = f:read("*a")
        f:close()

        local ok, data = pcall(vim.mpack.decode, content)

        if ok and type(data) == "table" and type(data.lines) == "table" then
          local time = os.date("%d %b %H:%M", data.timestamp)
          local cwd = data.cwd:gsub(vim.fn.expand("~"), "~")

          local line = data.id .. " | " .. cwd .. " | " .. time
          table.insert(display, line)

          map[line] = file:gsub("%.mpack$", "")
        end
      end
    end

    ::continue::
  end

  if #display == 0 then
    vim.notify("No valid terminal sessions found", vim.log.levels.WARN)
    return
  end

  table.sort(display)

  vim.cmd("new")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, display)

  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false

  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_get_current_line()
    local filename = map[line]

    if not filename then
      vim.notify("Invalid selection", vim.log.levels.WARN)
      return
    end
    vim.cmd("bd!")
    M.restore_terminal(filename)
  end, { buffer = true })

  vim.notify("Select a session and press ENTER", vim.log.levels.INFO)
end


-- ======================
-- RESTORE INTO A REAL TERMINAL BUFFER
-- ======================
function M.restore_terminal(filename)
  if not filename or not filename:match("^term_%d+") then
    vim.notify("Invalid filename", vim.log.levels.ERROR)
    return
  end

  local dir = get_data_dir()
  local path = dir .. filename .. ".mpack"

  local file = io.open(path, "rb")
  if not file then
    vim.notify("File not found: " .. path, vim.log.levels.ERROR)
    return
  end

  local content = file:read("*a")
  file:close()

  local ok, data = pcall(vim.mpack.decode, content)
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then
    vim.notify("Invalid session file", vim.log.levels.ERROR)
    return
  end

  -- Create a buffer and open a REAL pseudo-terminal (no process attached)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)

  -- THIS IS THE KEY: nvim_open_term() creates a real terminal buffer
  -- with a libvterm instance. Data fed via nvim_chan_send() flows through
  -- libvterm and produces REAL scrollback — not just buffer lines.
  local chan = vim.api.nvim_open_term(buf, {})

  -- Feed saved lines as terminal output.
  -- Lines that scroll off the visible area become real scrollback.
  local output = table.concat(data.lines, "\r\n")
  vim.api.nvim_chan_send(chan, output)

  -- Mark as restored so user knows this isn't a live process
  vim.api.nvim_chan_send(chan, "\r\n\027[90m[Restored from session]\027[0m\r\n")

  -- Set buffer name to original URI if available
  if data.uri then
    pcall(vim.api.nvim_buf_set_name, buf, data.uri .. "#restored")
  end

  vim.notify("Terminal restored (real scrollback) from: " .. path)
  return buf, chan
end
return M