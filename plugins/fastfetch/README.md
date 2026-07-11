# fastfetch

Prints a [fastfetch](https://github.com/fastfetch-cli/fastfetch) system-info banner
(OS, host, CPU, board, memory, disk...) with a custom logo + color theme, cached so
it appears **instantly** in a new terminal instead of adding a visible startup delay.

## Why cached instead of run-on-every-launch

Spawning fastfetch live costs **~24ms** every time — noticeable, and worse on
battery when the CPU is throttled. Almost none of that is the config: per-module
data collection is ~0.4ms and parsing the theme file is ~1ms. The rest is the
process itself starting up, a cost every external tool pays (a different
implementation language wouldn't avoid it).

So this plugin renders the banner once, caches the colored output to a file, and on
every new shell just **prints that file** (~1.5ms — no process spawned, flat on
battery). Run `ff` whenever you want a live refresh (fresh memory/disk stats) — it
re-renders, updates the cache, and shows it.

## Commands

| Command             | Does |
|----------------------|------|
| *(open a new shell)* | Prints the cached banner instantly (~1.5ms). |
| `ff`                  | Renders fastfetch live, refreshes the cache, shows the result. Run this after editing the theme, or anytime you want current stats. |
| `ff --logo windows`   | Live render with fastfetch's built-in Windows logo for that one run (doesn't touch your saved theme). |

## Default logo: Windows

Out of the box — before you've created a theme file — there's nothing for fastfetch
to load, so it falls back to **its own built-in Windows logo**. You get a working
banner immediately; customizing the logo is opt-in.

## Add your own logo

Everything about the look (logo art, logo colors, module icons, key colors) lives in
one file:

```
%USERPROFILE%\Documents\ps\fastfetch\config.jsonc
```

That file doesn't exist until you create it. To set up a custom logo:

1. Create the folder `Documents\ps\fastfetch\` if it doesn't exist yet.
2. Put your ASCII/Braille art there, e.g. `Documents\ps\fastfetch\mylogo.txt`.
3. Create `Documents\ps\fastfetch\config.jsonc` with at least:
   ```jsonc
   {
     "logo": {
       "type": "file",
       "source": "C:/Users/<you>/Documents/ps/fastfetch/mylogo.txt"
     }
   }
   ```
4. Run `ff`. The cache refreshes and your logo is now what every new shell shows.

### Self-healing config

`ff` checks the theme file on every run and repairs two common mistakes automatically,
printing a `[ff] repaired config.jsonc ...` note when it does:

- **Stale `source` path** — if the path in `"source"` doesn't exist, but a file with
  that same *name* exists in your `Documents\ps\fastfetch\` folder, the path gets
  rewritten to point there. (This is exactly what happens if you paste a sample
  config from another machine/user without editing the path — see below.)
- **Unsupported icon glyphs** — `pwsh-terminal-setup`'s bundled font (LigaConsolas
  Nerd Font) is missing a few newer Nerd Font icons that fastfetch themes commonly
  use for `cpu`, `board`, and `memory` (they'd otherwise render as `▯`/`□`). `ff`
  swaps them for equivalents the font actually has.

So a copy-pasted or slightly wrong config still ends up rendering correctly after one
`ff`.

## Sample: the lion logo

[`samples/lion.txt`](samples/lion.txt) and [`samples/lion_config.jsonc`](samples/lion_config.jsonc)
are a ready-to-use custom logo + Catppuccin-ish theme, included as a working example.

To use it:

```powershell
# from the pwsh-plugins repo root
Copy-Item plugins\fastfetch\samples\lion.txt "$HOME\Documents\ps\fastfetch\lion.txt"
Copy-Item plugins\fastfetch\samples\lion_config.jsonc "$HOME\Documents\ps\fastfetch\config.jsonc"
ff
```

The sample's `"source"` path is a placeholder (`C:/Users/Administrator/...`) — you
don't need to fix it by hand. Since the copied `lion.txt` sits next to your new
`config.jsonc` with a matching filename, the **self-healing** step above corrects the
path on the very first `ff` run.

## Startup modes

Near the top of the installed plugin there's one setting:

```powershell
$__ffMode = 'cached'   # 'cached' | 'manual' | 'always'
```

| Mode | Behavior |
|------|----------|
| `cached` *(default)* | Prints the cached snapshot on every new shell (~1.5ms). Stats reflect the last `ff` run. |
| `manual` | Shows nothing on startup — type `ff` whenever you want the banner. |
| `always` | Runs fastfetch live on every new shell (~24ms, the cost this plugin exists to avoid). |

To change it, edit that line, then reinstall: `.\addconfig.ps1 --fastfetch --force`.

## Troubleshooting

- **Icons show as boxes/`▯`** — make sure `pwsh-terminal-setup`'s Nerd Font patch has
  been applied to your Windows Terminal profile, and that you've run `ff` at least
  once since editing the theme (see self-healing, above).
- **Edited `config.jsonc` but nothing changed** — you have to run `ff` to refresh the
  cache; just saving the file isn't enough, since new shells print the cached
  snapshot, not the live file.
- **Banner never changes no matter what you do** — fastfetch has its own built-in
  config search path and checks `~/.config/fastfetch/config.jsonc` *before* anything
  else in some resolution orders. If that file exists (e.g. left over from running
  `fastfetch --gen-config` once, or from following fastfetch's own docs), it can
  silently win over this plugin's `Documents\ps\fastfetch\config.jsonc`. Delete or
  rename `~/.config/fastfetch/` if you don't intend to use it.

## Dependencies

- **fastfetch**:
  ```powershell
  winget install --id Fastfetch-cli.Fastfetch -e
  ```
  If it's missing, `ff` prints that install command instead of failing.

## Behavior

| Situation | Prints on shell start? |
|---|---|
| Interactive shell (Windows Terminal) | Yes — cached snapshot |
| `pwsh -NoExit ...` | Yes — cached snapshot |
| `pwsh -Command ...` / `-c` | No |
| `pwsh -File script.ps1` / `-f` | No |
| `pwsh -NonInteractive ...` | No |
| fastfetch not installed | No (no-op; `ff` warns with the install command) |

The interactivity check inspects `[Environment]::GetCommandLineArgs()`, so
non-interactive runs (scripts, CI, one-liners) pay effectively nothing.

## Add it

```powershell
.\addconfig.ps1 --fastfetch
```
