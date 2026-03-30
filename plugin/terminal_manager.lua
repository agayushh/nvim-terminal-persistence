local term = require("terminal_manager")

-- ======================
-- USER COMMANDS
-- ======================
vim.api.nvim_create_user_command("TerminalSave", term.save, {})

vim.api.nvim_create_user_command("TerminalRestore", function(opts)
  term.restore_terminal(opts.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command("TerminalList", function()
  term.list()
end, {})

vim.api.nvim_create_user_command("TerminalSaveAll", term.save_all, {})

vim.api.nvim_create_user_command("TerminalRestoreAll", term.restore_all, {})

vim.api.nvim_create_user_command("TerminalCleanup", function(opts)
  local max = tonumber(opts.args ~= "" and opts.args or nil)
  term.cleanup(max)
end, { nargs = "?" })

-- ======================
-- AUTOCMD
-- ======================
-- Auto-save terminal scrollback when a terminal buffer is closed.
-- This mirrors how undo/swap files work: no manual action needed.
vim.api.nvim_create_autocmd("TermClose", {
  group = vim.api.nvim_create_augroup("TermPersistence", { clear = true }),
  callback = function(ev)
    -- Schedule so the buffer is still accessible
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(ev.buf) then
        term.save(ev.buf)
      end
    end)
  end,
})