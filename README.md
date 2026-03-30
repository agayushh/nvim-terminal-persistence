# Neovim Terminal Scrollback Persistence (Prototype)

## Features
- Save terminal output
- Store sessions using msgpack
- List saved sessions
- Restore sessions (prototype)

## Commands

:TerminalSave  
:TerminalList  
:TerminalRestore <id>

## Notes

- Current implementation restores content into a buffer
- True terminal scrollback restoration is planned using Neovim terminal internals