# argument-completers

Native `Tab` completion for the tools you use most. Both completers are
registered only when their command exists, so the plugin is safe on any machine.

## What it adds

| Command  | Completion                                                        |
| -------- | ---------------------------------------------------------------- |
| `git`    | Local branch names for `checkout`, `switch`, `merge`, `rebase`   |
| `winget` | Full official native completer (subcommands, options, package IDs)|

The git completer reads branches from
`git for-each-ref --format='%(refname:short)' refs/heads` and filters by what
you have typed. Outside a repository it simply returns nothing.

The winget completer is the standard block from Microsoft's docs; it calls
`winget complete` and sets UTF-8 encoding so package names render correctly.

## Dependencies

None required. Completion for a given tool only activates when that tool
(`git` and/or `winget`) is installed and on `PATH`.

## Startup cost

`~0ms` — registering completers is cheap; the work happens only when you press
`Tab`.

## Examples

```powershell
git switch fea<Tab>     # -> feature/login, feature/logout, ...
git merge <Tab>         # lists all local branches
winget install Git.<Tab>
```

## Add it

```powershell
.\addconfig.ps1 --argument-completers.config
```
