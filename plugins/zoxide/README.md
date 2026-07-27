# zoxide

A smarter `cd`. [zoxide](https://github.com/ajeetdsouza/zoxide) remembers the
directories you visit and lets you jump to them by a fragment of their name.

## Commands

| Command      | What it does                                             |
| ------------ | -------------------------------------------------------- |
| `z <dir>`    | Jump to the best-matching directory you've visited       |
| `z a b`      | Jump using multiple keywords (matches a path with both)  |
| `zi <dir>`   | Interactive pick from matches (requires fzf for the UI)   |
| `z -`        | Jump back to the previous directory                      |

zoxide learns as you navigate, so the more you use normal `cd`/`z`, the better
its ranking gets.

## Dependencies

- **zoxide**: install with:

  ```powershell
  winget install --id ajeetdsouza.zoxide -e
  ```

If zoxide is not installed, this plugin does nothing (the guard skips it), so
it is safe to enable ahead of time.

## Startup cost

`~5ms`. Runs `zoxide init powershell` once at load to register the hook.

## Examples

```powershell
z proj        # jump to ...\Documents\ps\my-project
z dl          # jump to the Downloads folder you visited earlier
zi doc        # interactively choose among matching "doc" directories
```

## Add it

```powershell
.\addconfig.ps1 --zoxide.config
```
