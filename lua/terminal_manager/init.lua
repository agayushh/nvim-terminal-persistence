local M = {}

local function get_data_dir()
  return vim.fn.stdpath("data") .. "/neovim/terminals/"
end

-- ======================
-- SAVE TERMINAL OUTPUT
-- ======================
function M.save()
  local buf = vim.api.nvim_get_current_buf()

  if vim.bo.buftype ~= "terminal" then
    print("Not a terminal buffer")
    return
  end

  local line_count = vim.api.nvim_buf_line_count(buf)
  local lines = {}

  for i = 1, line_count do
    local l = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
    if l and l:match("%S") then
      table.insert(lines, l)
    end
  end

  if #lines == 0 then
    print("No terminal content to save")
    return
  end

  local dir = get_data_dir()
  vim.fn.mkdir(dir, "p")

  local id = "term_" .. os.time() .. "_" .. math.random(1000,9999)
  local path = dir .. id .. ".mpack"

  local data = {
    version = 1,
    id = id,
    cwd = vim.fn.getcwd(),
    timestamp = os.time(),
    lines = lines,
  }

  local packed = vim.mpack.encode(data)

  local file = io.open(path, "wb")
  if not file then
    print("Failed to save")
    return
  end

  file:write(packed)
  file:close()

  print("Saved to: " .. path)
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
    print("No valid terminal sessions found")
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
      print("Invalid selection")
      return
    end
    vim.cmd("bd!")
    M.restore_terminal(filename)
  end, { buffer = true })

  print("Select a session and press ENTER")
end


-- ======================
-- REPLAY TERMINAL OUTPUT
-- ======================
function M.restore_terminal(filename, delay)
  if not filename or not filename:match("^term_%d+") then
    print("Invalid filename")
    return
  end

  delay = delay or 50

  local dir = get_data_dir()
  local path = dir .. filename .. ".mpack"

  local file = io.open(path, "rb")
  if not file then
    print("File not found: " .. path)
    return
  end

  local content = file:read("*a")
  file:close()

  local ok, data = pcall(vim.mpack.decode, content)
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then
    print("Invalid file")
    return
  end

  vim.cmd("new")

  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false

  vim.api.nvim_buf_set_lines(0, 0, -1, false, {})

  local i = 1
  local total = #data.lines
  local stopped = false

  vim.keymap.set("n", "q", function()
    stopped = true
  end, { buffer = true })

  local function play()
    if stopped then
      print("Replay stopped")
      return
    end

    if i > total then
      print("Replay finished")
      return
    end

    vim.api.nvim_buf_set_lines(0, -1, -1, false, { data.lines[i] })
    vim.cmd("normal! G")

    i = i + 1
    vim.defer_fn(play, delay)
  end

  play()
end
return M