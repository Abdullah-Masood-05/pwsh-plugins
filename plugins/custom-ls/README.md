# custom-ls

A colorized `ls` with **no external modules** — just `Get-ChildItem` plus ANSI
escape codes. Names are colored by type and extension so directories, code,
images, and archives stand out at a glance.

## Commands

| Command | What it does                                    |
| ------- | ----------------------------------------------- |
| `ls`    | Colorized listing (forwards all args to `Get-ChildItem`) |
| `l`     | Short alias for `ls`                             |

Because every argument is forwarded, the usual switches all work:
`ls -Force`, `ls C:\Windows -Filter *.dll`, `ls ..`, and so on.

## Color map

| Category    | Color         | Example extensions                     |
| ----------- | ------------- | -------------------------------------- |
| Directory   | bold blue     | (folders)                              |
| Archive     | bold red      | `.zip` `.7z` `.tar` `.gz` `.rar`       |
| Image       | bold magenta  | `.png` `.jpg` `.gif` `.svg` `.webp`    |
| Code        | bold yellow   | `.ps1` `.py` `.js` `.ts` `.cs` `.json` |
| Document    | bold cyan     | `.md` `.txt` `.pdf` `.docx` `.csv`     |
| Executable  | bold green    | `.exe` `.msi` `.bat` `.cmd`            |
| Default     | terminal default | everything else                     |

## Dependencies

None. Requires an ANSI-capable terminal (Windows Terminal, VS Code) for color;
falls back gracefully otherwise.

## Startup cost

`~0ms` — only defines two functions and two lookup tables at load.

## Notes

- When output is **redirected** (`ls | ...` or `ls > out.txt`), raw
  `FileSystemInfo` objects are returned instead of colored text, so pipelines
  and captures behave exactly like `Get-ChildItem`.

## Add it

```powershell
.\addconfig.ps1 --custom-ls.config
```
