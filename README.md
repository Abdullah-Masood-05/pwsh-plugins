<h1 align="center">pwsh-plugins</h1>

<p align="center">
  <strong>A modular plugin ecosystem for PowerShell 7. Add only the features you want, keep your shell fast.</strong>
</p>

<p align="center">
  <a href="https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows"><img alt="PowerShell 7+" src="https://img.shields.io/badge/PowerShell-7%2B-5391FE?logo=powershell&logoColor=white"></a>
  <a href="https://aka.ms/terminal"><img alt="Windows 10/11" src="https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows11&logoColor=white"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/github/license/Abdullah-Masood-05/pwsh-plugins?color=1E4E79"></a>
  <a href="https://github.com/Abdullah-Masood-05/pwsh-plugins/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/Abdullah-Masood-05/pwsh-plugins?style=social&logo=github"></a>
</p>

<p align="center">
  ⭐ <b>Enjoying pwsh-plugins?</b> If it's useful to you, please <a href="https://github.com/Abdullah-Masood-05/pwsh-plugins">star it on GitHub</a>. It's free and it helps other developers find it.
</p>

<p align="center">
  <a href="#overview--philosophy"><b>Overview</b></a> ·
  <a href="#quick-start"><b>Quick start</b></a> ·
  <a href="#plugin-catalog"><b>Catalog</b></a> ·
  <a href="#usage"><b>Usage</b></a> ·
  <a href="#create-your-own-plugin"><b>Create a plugin</b></a> ·
  <a href="#troubleshooting"><b>Troubleshooting</b></a> ·
  <a href="https://github.com/Abdullah-Masood-05/pwsh-terminal-setup"><b>pwsh-terminal-setup</b></a>
</p>

---

`pwsh-plugins` is a plugin manager for your PowerShell 7 profile. Each plugin is a small, self-contained
`.config` snippet you opt into with one command. Install `git-aliases` and `zoxide`, skip everything else,
and your startup only pays for what you pick. Three scripts (`addconfig.ps1`, `removeconfig.ps1`, `listconfigs.ps1`)
handle install, removal, dependency resolution, and profile backups.

## Overview & philosophy

- **Minimalism by default.** A bare install adds nothing to your shell. You start from zero and add exactly the pieces you want.
- **Opt-in extensions.** Nothing is enabled behind your back. Every feature is a plugin you explicitly install by name.
- **Zero performance penalty.** Only the plugins you install touch startup. The manager itself doesn't run at shell launch, it just edits your profile.
- **Modular & self-contained.** Each plugin is one `.config` file with a metadata header and a PowerShell body. Read it, audit it, fork it: no hidden runtime.

It's built as an add-on to **[`pwsh-terminal-setup`](https://github.com/Abdullah-Masood-05/pwsh-terminal-setup)**
(a minimal, ultra-fast PowerShell 7 + Windows Terminal setup with a clean zsh-like prompt), but it has no
dependency on it and **works standalone** on any PowerShell 7 profile.

## Quick start

```powershell
git clone https://github.com/Abdullah-Masood-05/pwsh-plugins.git
cd pwsh-plugins
.\listconfigs.ps1                                   # see what's available
.\addconfig.ps1 --git-aliases.config --zoxide.config
# restart the terminal (or: . $PROFILE.CurrentUserAllHosts)
```

If your execution policy blocks the script, run it through `pwsh` instead:

```powershell
pwsh -ExecutionPolicy Bypass -File .\addconfig.ps1 --git-aliases.config --zoxide.config
```

## Plugin catalog

| Plugin | What it adds | Startup cost | External dependency |
|---|---|---|---|
| `git-aliases` | Git shortcuts: `gco`, `gcb`, `gcm`, `gca`, `gaa`, `gst`, `gpl`, `gps`, `gd`, `gl` | ~0 ms | git |
| `zoxide` | Smart `z` directory jumping | ~5 ms | zoxide (`winget: ajeetdsouza.zoxide`) |
| `fastfetch` | System-info banner at startup | ~15 ms | fastfetch (`winget: Fastfetch-cli.Fastfetch`) |
| `psreadline-bindings` | Zsh-like keys: `Ctrl+Z` undo, `Alt+←/→` word jump, `Ctrl+Backspace`/`Delete` delete-word | ~0 ms | none |
| `argument-completers` | Tab completion for git branches and winget | ~0 ms | none |
| `custom-ls` | Colored `ls` output, no external module | ~0 ms | none |
| `navigation-shortcuts` | `..`, `...`, `....`, `mkcd`, `home` | ~0 ms | none |

Each plugin also ships its own README under `plugins/<name>/` with the full command list and any caveats.

## Usage

Three scripts drive everything. All of them accept `-ProfilePath <path>` to target a profile other than
the default `$PROFILE.CurrentUserAllHosts` (handy for testing).

### `addconfig.ps1`: install plugins

```powershell
.\addconfig.ps1 --git-aliases.config --zoxide.config     # install one or more
.\addconfig.ps1 --all                                    # install everything
.\addconfig.ps1 --zoxide.config --whatif                 # dry run, change nothing
.\addconfig.ps1 --fastfetch.config --force               # reinstall / refresh a plugin
```

| Flag | Effect |
|---|---|
| `--<name>.config` | Install a plugin by name (repeatable) |
| `--all` | Install every available plugin |
| `--list` | List available plugins and exit |
| `--force` | Reinstall a plugin even if it's already present |
| `--whatif` | Dry run: print what would change, write nothing |
| `--verbose` | Show detailed resolution and write steps |
| `--backup-list` | List saved profile backups with their ids |
| `--restore <id>` | Restore the profile from a backup id |
| `-ProfilePath <path>` | Target a specific profile file |

What it does on install:

- **Validates** each requested plugin exists and has a well-formed header.
- **Resolves `# Dependencies:`**: other plugins a plugin needs; prompts to add any that are missing.
- **Checks `# Requires:`** external tools (e.g. `git`, `zoxide`); if one isn't on `PATH`, it offers to run `winget install` for you.
- **Backs up the profile** before writing, keeping the **last 5** backups.
- Is **idempotent**: already-installed plugins are skipped unless you pass `--force`.

### `removeconfig.ps1`: uninstall plugins

```powershell
.\removeconfig.ps1 --fastfetch.config                    # remove one
.\removeconfig.ps1 --all                                 # remove every installed plugin
.\removeconfig.ps1 --zoxide.config --whatif              # preview the removal
```

| Flag | Effect |
|---|---|
| `--<name>.config` | Remove a plugin by name (repeatable) |
| `--all` | Remove every installed plugin |
| `--whatif` | Dry run: preview the removal, write nothing |
| `-ProfilePath <path>` | Target a specific profile file |

It **lists what it will remove first**, **backs up** the profile before modifying it, and **warns** if
another installed plugin still depends on the one you're removing.

### `listconfigs.ps1`: see what's available and installed

```powershell
.\listconfigs.ps1                                        # all available plugins (default)
.\listconfigs.ps1 --installed                            # only what's in your profile
.\listconfigs.ps1 --available                            # only what you haven't installed
.\listconfigs.ps1 --info zoxide                          # full metadata for one plugin
```

| Flag | Effect |
|---|---|
| _(default)_ | List all available plugins |
| `--installed` | List only plugins currently installed in the profile |
| `--available` | List only plugins not yet installed |
| `--info <plugin>` | Show the full metadata header for one plugin |
| `-ProfilePath <path>` | Target a specific profile file |

## How it works

Each plugin is a `.config` file: a **metadata header** followed by the PowerShell **body**.

```powershell
# Plugin: zoxide
# Version: 1.0.0
# Dependencies:
# Requires: zoxide|ajeetdsouza.zoxide
# Startup Cost: ~5 ms

# --- body: plain PowerShell that runs at shell startup ---
Invoke-Expression (& { (zoxide init powershell | Out-String) })
```

The header fields:

| Field | Meaning |
|---|---|
| `# Plugin:` | Canonical plugin name (matches the folder and file base name) |
| `# Version:` | Plugin version |
| `# Dependencies:` | Other **plugins** this one needs (comma-separated; empty if none) |
| `# Requires:` | External **tools** as `cmd|winget-id` (comma-separated; empty if none) |
| `# Startup Cost:` | Rough time the body adds to shell launch |

On install, `addconfig.ps1` wraps the body between markers and appends the block to
`$PROFILE.CurrentUserAllHosts`:

```powershell
# >>> pwsh-plugins:zoxide >>>
Invoke-Expression (& { (zoxide init powershell | Out-String) })
# <<< pwsh-plugins:zoxide <<<
```

`removeconfig.ps1` strips that exact block back out. Because everything lives inside named markers, the
manager can add, remove, and detect plugins without disturbing the rest of your profile, and **nothing is
loaded that you didn't install**.

## Create your own plugin

1. Copy the template into a new plugin folder:

   ```powershell
   Copy-Item templates\plugin-template.config plugins\my-plugin\my-plugin.config
   ```

2. **Fill the metadata header**: `# Plugin:`, `# Version:`, `# Dependencies:`, `# Requires:`, `# Startup Cost:`.
3. **Write the body.** Guard anything interactive or slow so a normal startup stays ~0 ms. Only run heavy
   work on first use or behind a check, not on every shell launch.
4. **Add `plugins/my-plugin/README.md`** describing what it adds and how to use it.
5. Install it:

   ```powershell
   .\addconfig.ps1 --my-plugin.config
   ```

**Naming rule:** the folder name, the `.config` file base name, and the `# Plugin:` value must all match
(`plugins/my-plugin/my-plugin.config` with `# Plugin: my-plugin`).

**Dependencies vs. Requires:**

- `# Dependencies:`: other **plugins** in this repo (installed for you if missing).
- `# Requires:`: external **tools**, written as `cmd|winget-id` (e.g. `zoxide|ajeetdsouza.zoxide`) so the
  manager can detect them on `PATH` and offer a `winget install`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| **Execution policy error** running a script | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, or run via `pwsh -ExecutionPolicy Bypass -File .\addconfig.ps1 ...` |
| **Changes didn't apply** after install | Restart the terminal, or reload the profile: `. $PROFILE.CurrentUserAllHosts` |
| **External tool still missing** after install | Install it yourself: `winget install --id <id> -e`, then reopen the terminal |
| **Need to roll back the profile** | `.\addconfig.ps1 --backup-list` to see saved backups, then `.\addconfig.ps1 --restore <id>` |

## Comparison

How this differs from framework-style setups like **Oh My Posh** or **oh-my-zsh**:

- **No runtime framework.** There's no engine that loads on every prompt or shell launch. The manager only
  edits your profile, then gets out of the way.
- **You inject exactly what you pick.** Installed plugins are plain snippets appended to your profile, nothing more.
- **Readable PowerShell.** Every plugin is a short `.config` file you can open and understand: no plugin loader, no theme DSL.
- **Near-zero base startup.** A fresh install adds 0 ms; each plugin's cost is listed up front so you can budget it.

Frameworks buy you a large curated ecosystem and theming out of the box; `pwsh-plugins` trades that for a
smaller, transparent, pay-for-what-you-use model. Pick whichever fits how you work.

## Contributing

- Fork the repo and add a plugin under `plugins/<name>/`, following the template and naming rules above.
- Keep it **fast** (guard slow/interactive code) and **self-contained** (no hidden state, no surprise dependencies).
- **One plugin per PR**, and include a `plugins/<name>/README.md`.

## License

[MIT](LICENSE)

---

<p align="center">
  Companion to <a href="https://github.com/Abdullah-Masood-05/pwsh-terminal-setup"><b>pwsh-terminal-setup</b></a>,
  a fast, good-looking PowerShell 7 + Windows Terminal setup.
  <br>
  Docs: <a href="https://abdullah-masood-05.github.io/pwsh-terminal-setup/">abdullah-masood-05.github.io/pwsh-terminal-setup</a>
</p>
