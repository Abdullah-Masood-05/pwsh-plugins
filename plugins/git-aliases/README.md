# git-aliases

Short Git shortcut functions for the commands you type all day. Every function
uses `@args` splatting, so extra flags pass straight through to `git`.

## Commands

| Function | Runs                                    |
| -------- | --------------------------------------- |
| `gco`    | `git checkout`                          |
| `gcb`    | `git checkout -b`                       |
| `gcm`    | `git commit -m`                         |
| `gca`    | `git commit -am`                        |
| `gaa`    | `git add -A`                            |
| `gst`    | `git status`                            |
| `gpl`    | `git pull`                              |
| `gps`    | `git push`                              |
| `gd`     | `git diff`                              |
| `gl`     | `git log --oneline --graph --decorate`  |

## Dependencies

- **git**: install with:

  ```powershell
  winget install --id Git.Git -e
  ```

## Startup cost

`~0ms`. Just function definitions, nothing runs at load time.

## Examples

```powershell
gcb feature/login      # git checkout -b feature/login
gaa                    # stage everything
gcm "add login form"   # commit with a message
gps                    # push
gl -n 20               # last 20 commits as a graph (extra flag passes through)
```

## Add it

```powershell
.\addconfig.ps1 --git-aliases.config
```
