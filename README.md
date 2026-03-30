# Neovim Terminal Scrollback Persistence

GSoC prototype for [neovim/neovim#28297](https://github.com/neovim/neovim/issues/28297)

## How It Works

```
Save: terminal buffer → nvim_buf_get_lines() → vim.mpack.encode() → stdpath("state")/term/*.mpack
Restore: mpack file → vim.mpack.decode() → nvim_open_term() + nvim_chan_send() → real terminal buffer
```

The key insight: `nvim_open_term()` creates a real terminal buffer backed by libvterm.
Data fed via `nvim_chan_send()` flows through the terminal emulator and produces
**real scrollback** in `sb_buffer[]` — not plain text in a normal buffer.

## Features

- **Save** terminal scrollback to `stdpath("state")/term/` using msgpack
- **Restore** into a real `buftype=terminal` buffer with proper scrollback
- **Auto-save** on `TermClose` (like undo/swap files — no manual action needed)
- **List** saved sessions with interactive picker
- **Save/Restore all** terminal buffers at once

## Commands

| Command | Description |
|---------|-------------|
| `:TerminalSave` | Save current terminal buffer |
| `:TerminalSaveAll` | Save all open terminal buffers |
| `:TerminalRestore <id>` | Restore a specific saved session |
| `:TerminalRestoreAll` | Restore all saved sessions at once |
| `:TerminalList` | Browse and restore saved sessions |
| `:TerminalCleanup [max]` | Remove oldest sessions beyond limit (default: 50) |
## Design Decisions

- **`stdpath("state")/term/`** — matches justinmk's spec: *"Similar to undo/swap/backup directories"*
- **msgpack** — native to Neovim (ShaDa, RPC). Not JSON.
- **`nvim_open_term()` + `nvim_chan_send()`** — the only way to populate real libvterm scrollback
- **Saves `term://` URI, cwd, dimensions** — ready for `:mksession` integration

## What This Prototype Demonstrates

This is a Lua-level proof-of-concept. The GSoC project will move the critical
path to C for full-fidelity restoration:

1. Serialize `VTermScreenCell` data from `sb_buffer[]` (including colors/attrs)
2. Reconstruct ANSI SGR escape sequences for color-accurate restore
3. Integrate with `makeopens()` in `src/nvim/ex_session.c`
4. Add continuous auto-save (debounced, like swap files)