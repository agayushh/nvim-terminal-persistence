local term = require("terminal_manager")

vim.api.nvim_create_user_command("TerminalSave", term.save, {})

vim.api.nvim_create_user_command("TerminalRestore", function(opts)
  term.restore_terminal(opts.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command("TerminalList", function()
  term.list()
end, {})