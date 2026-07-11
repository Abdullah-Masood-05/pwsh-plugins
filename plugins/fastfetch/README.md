# fastfetch

Prints a [fastfetch](https://github.com/fastfetch-cli/fastfetch) system-info
banner (OS, host, CPU, GPU, memory, uptime...) each time you open an
**interactive** PowerShell session.

## Behavior

| Situation                              | Runs fastfetch? |
| -------------------------------------- | --------------- |
| Interactive shell (Windows Terminal)   | Yes             |
| `pwsh -NoExit ...`                      | Yes             |
| `pwsh -Command ...` / `-c`             | No              |
| `pwsh -File script.ps1` / `-f`         | No              |
| `pwsh -NonInteractive ...`             | No              |
| fastfetch not installed                | No (no-op)      |

The interactivity check inspects `[Environment]::GetCommandLineArgs()`, so
non-interactive runs (scripts, CI, one-liners) pay effectively nothing.

## Dependencies

- **fastfetch** — install with:

  ```powershell
  winget install --id Fastfetch-cli.Fastfetch -e
  ```

## Startup cost

`~15ms` in interactive shells; `~0ms` everywhere else. Configure the banner
via fastfetch's own config (`fastfetch --gen-config`) if you want it leaner.

## Add it

```powershell
.\addconfig.ps1 --fastfetch.config
```
