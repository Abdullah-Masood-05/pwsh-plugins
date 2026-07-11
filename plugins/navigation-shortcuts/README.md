# navigation-shortcuts

Tiny functions for moving around the filesystem faster.

## Commands

| Command       | What it does                                          |
| ------------- | ----------------------------------------------------- |
| `..`          | Go up one directory (`Set-Location ..`)               |
| `...`         | Go up two directories                                 |
| `....`        | Go up three directories                               |
| `mkcd <path>` | Create a directory (with parents) and `cd` into it    |
| `home`        | Jump to `$HOME`                                        |

`mkcd` uses `-LiteralPath` when switching in, so paths with special characters
(like `[`, `]`) are handled correctly.

## Dependencies

None. Pure PowerShell, portable, no external tools.

## Startup cost

`~0ms` — just function definitions.

## Examples

```powershell
..                 # up one level
....               # up three levels
mkcd src/app/api   # creates the tree and drops you inside it
home               # back to your home directory
```

## Add it

```powershell
.\addconfig.ps1 --navigation-shortcuts.config
```
