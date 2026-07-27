# psreadline-bindings

Zsh-like [PSReadLine](https://github.com/PowerShell/PSReadLine) key bindings for
quicker line editing. Loaded only in interactive sessions and wrapped in a
`try{}`, so it never errors or slows down scripts.

## Key bindings

| Key              | Action               | PSReadLine function   |
| ---------------- | -------------------- | --------------------- |
| `Ctrl+z`         | Undo last edit       | `Undo`                |
| `Alt+Left`       | Move back one word   | `BackwardWord`        |
| `Alt+Right`      | Move forward one word| `ForwardWord`         |
| `Ctrl+Backspace` | Delete word left     | `BackwardDeleteWord`  |
| `Ctrl+Delete`    | Delete word right    | `DeleteWord`          |

> Note: the companion `pwsh-terminal-setup` profile already binds
> `Ctrl+Left/Right` for word movement. This plugin uses **Alt** for the same
> motion so the two complement each other instead of clashing.

## Dependencies

None external. PSReadLine ships with PowerShell 7; if it is somehow missing,
the plugin quietly does nothing.

## Startup cost

`~0ms`. A handful of `Set-PSReadLineKeyHandler` calls, interactive only.

## Add it

```powershell
.\addconfig.ps1 --psreadline-bindings.config
```
