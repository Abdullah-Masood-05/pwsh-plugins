<#
.SYNOPSIS
    Injects opt-in pwsh-plugins snippets into your PowerShell profile.

.DESCRIPTION
    Reads plugins from .\plugins\<name>\<name>.config and wraps each one in a
    labelled marker block inside $PROFILE.CurrentUserAllHosts (or a -ProfilePath
    override). Idempotent and safe to re-run: the profile is backed up before
    every change, existing blocks are detected by their markers, and the whole
    profile is read once / written once so a batch install shares one backup.

    Plugins are chosen with --<name> flags (the trailing .config is optional),
    a bare <name>, or --all. Dependencies on other plugins and required external
    tools are resolved interactively.

.PARAMETER Selection
    All remaining tokens: plugin names / flags. Recognised flags (case-insensitive):
      --all              install every plugin under .\plugins
      --list             print the available plugins and exit
      --whatif  / -WhatIf   dry run: print what would change, modify nothing
      --force   / -Force    reinstall even if already present
      --verbose / -Verbose  extra logging
      --backup-list      list existing profile backups and exit
      --restore <id>     restore the profile from backup <id> and exit
      --help    / -h     show usage and exit
      --<name>[.config]  a plugin to install (also accepts a bare <name>)

.PARAMETER ProfilePath
    Target profile file. Defaults to $PROFILE.CurrentUserAllHosts. Provide a
    temp path to test against a throwaway file.

.EXAMPLE
    .\addconfig.ps1 --git-aliases --zoxide

.EXAMPLE
    .\addconfig.ps1 --all --whatif

.EXAMPLE
    .\addconfig.ps1 --custom-ls --force

.EXAMPLE
    .\addconfig.ps1 --backup-list
    .\addconfig.ps1 --restore 20260711_170000
#>
param(
    [string] $ProfilePath
)

# All plugin names / --flags arrive via the automatic $args. We deliberately do NOT
# use a [Parameter(ValueFromRemainingArguments)] param: that would make this an
# advanced function, whose common parameters (-Verbose, -InformationAction, ...) would
# swallow tokens like --verbose / --info before our own parser ever sees them.
$Selection = $args

$ErrorActionPreference = 'Stop'

#region helpers -------------------------------------------------------------
function Write-Step ($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok   ($m) { Write-Host "    [ok] $m" -ForegroundColor Green }
function Write-Warn ($m) { Write-Host "    [!]  $m" -ForegroundColor Yellow }
function Write-Err  ($m) { Write-Host "    [x]  $m" -ForegroundColor Red }
function Write-Note ($m) { if ($script:verbose) { Write-Host "    [v]  $m" -ForegroundColor DarkGray } }

# plugins/<name>/<name>.config
function Get-PluginConfigPath ([string] $Name) {
    Join-Path (Join-Path $script:pluginsRoot $Name) "$Name.config"
}

# Names of every plugin folder that actually contains a matching .config.
function Get-PluginNames {
    if (-not (Test-Path -LiteralPath $script:pluginsRoot)) { return @() }
    Get-ChildItem -LiteralPath $script:pluginsRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "$($_.Name).config") } |
        Select-Object -ExpandProperty Name | Sort-Object
}

# Parse the leading "# Key: Value" header (stops at the first non-matching line).
function Get-PluginMetadata ([string] $ConfigPath) {
    $lines = Get-Content -LiteralPath $ConfigPath
    $meta = [ordered]@{}
    foreach ($line in $lines) {
        if ($line -match '^#\s*([^:]+):\s*(.*)$') { $meta[$Matches[1].Trim()] = $Matches[2].Trim() }
        else { break }   # blank line / body starts here
    }
    [pscustomobject]@{
        Name         = $meta['Plugin']
        Description  = $meta['Description']
        Author       = $meta['Author']
        Version      = $meta['Version']
        Dependencies = $meta['Dependencies']
        Requires     = $meta['Requires']
        StartupCost  = $meta['Startup Cost']
        Raw          = $meta
    }
}

# "a, b, None" -> @('a','b') ; "None"/empty -> @()
function Get-ListValues ($value) {
    if (-not $value) { return @() }
    $v = "$value".Trim()
    if ($v -eq '' -or $v -ieq 'None') { return @() }
    @($v.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

# Is a block for <name> present in the profile text?
function Test-PluginInstalled ([string] $Content, [string] $Name) {
    if (-not $Content) { return $false }
    [regex]::IsMatch($Content, '(?m)^[ \t]*#\s*>>>\s*pwsh-plugins:' + [regex]::Escape($Name) + '[ \t]')
}

# Strip the whole marker block (plus up to one leading blank line) for <name>.
function Remove-PluginBlock ([string] $Content, [string] $Name) {
    $n = [regex]::Escape($Name)
    $open  = '#\s*>>>\s*pwsh-plugins:' + $n + '[ \t]'
    $close = '#\s*<<<\s*pwsh-plugins:' + $n + '[ \t]'
    [regex]::Replace($Content, '(?ms)(?:\r?\n){0,2}^[ \t]*' + $open + '.*?^[ \t]*' + $close + '[^\r\n]*', '')
}

# Wrap the verbatim .config in the injection markers.
function New-PluginBlock ([string] $ConfigPath, [string] $Name, [string] $Version) {
    $raw = (Get-Content -LiteralPath $ConfigPath -Raw).TrimEnd()
    "# >>> pwsh-plugins:$Name (v$Version) >>>`r`n$raw`r`n# <<< pwsh-plugins:$Name <<<"
}

# Copy the profile aside as <profile>.pwsh-plugins-bak.<id>, keep newest 5.
function Backup-Profile ([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    # Millisecond precision + a uniqueness bump so two backups in the same second
    # (e.g. install immediately followed by --restore) never share a filename and
    # clobber each other.
    $id  = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
    $bak = "$Path.pwsh-plugins-bak.$id"
    $n = 1
    while (Test-Path -LiteralPath $bak) { $bak = "$Path.pwsh-plugins-bak.${id}_$n"; $n++ }
    Copy-Item -LiteralPath $Path -Destination $bak -Force
    Get-ChildItem -Path "$Path.pwsh-plugins-bak.*" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -Skip 5 |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
    $bak
}

function Get-ProfileBackups ([string] $Path) {
    Get-ChildItem -Path "$Path.pwsh-plugins-bak.*" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        ForEach-Object {
            [pscustomobject]@{
                Id            = ($_.Name -replace '.*\.pwsh-plugins-bak\.', '')
                LastWriteTime = $_.LastWriteTime
                Path          = $_.FullName
            }
        }
}

function Restore-ProfileFromBackup ([string] $Path, [string] $Id) {
    $bak = "$Path.pwsh-plugins-bak.$Id"
    if (-not (Test-Path -LiteralPath $bak)) {
        Write-Err "backup id '$Id' not found ($bak)"
        $avail = Get-ProfileBackups $Path
        if ($avail) { Write-Host "    available ids: $(($avail.Id) -join ', ')" -ForegroundColor DarkGray }
        return $false
    }
    if (Test-Path -LiteralPath $Path) {
        $cur = Backup-Profile $Path
        if ($cur) { Write-Ok "backed up current profile -> $(Split-Path $cur -Leaf)" }
    } else {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    }
    Copy-Item -LiteralPath $bak -Destination $Path -Force
    Write-Ok "restored profile from backup '$Id'"
    $true
}

function Show-Usage {
    Write-Host @"
Usage: .\addconfig.ps1 [--<plugin> ...] [--all] [options]

  --all                 install every available plugin
  --<name>[.config]     install a plugin (bare <name> also works)
  --force,   -Force     reinstall even if already installed
  --whatif,  -WhatIf    dry run (print, change nothing)
  --verbose, -Verbose   extra logging
  --list                list available plugins and exit
  --backup-list         list profile backups and exit
  --restore <id>        restore profile from backup <id> and exit
  --help,    -h         show this help
  -ProfilePath <path>   target a specific profile file

Available plugins: $((Get-PluginNames) -join ', ')
"@ -ForegroundColor Gray
}
#endregion

#region argument parsing ----------------------------------------------------
if (-not $ProfilePath) { $ProfilePath = $PROFILE.CurrentUserAllHosts }
$script:pluginsRoot = Join-Path $PSScriptRoot 'plugins'
if (-not $Selection) { $Selection = @() }

$selectAll    = $false
$doList       = $false
$doBackupList = $false
$doRestore    = $false
$doHelp       = $false
$restoreId    = $null
$script:force   = $false
$script:whatIf  = $false
$script:verbose = $false
$requested    = @()
$unknownFlags = @()

$i = 0
while ($i -lt $Selection.Count) {
    $tok = $Selection[$i]
    $low = "$tok".ToLowerInvariant()
    if     ($low -eq '--all')                       { $selectAll    = $true }
    elseif ($low -eq '--list')                      { $doList       = $true }
    elseif ($low -eq '--backup-list')               { $doBackupList = $true }
    elseif ($low -in '--whatif', '-whatif')         { $script:whatIf  = $true }
    elseif ($low -in '--force', '-force')           { $script:force   = $true }
    elseif ($low -in '--verbose', '-verbose')       { $script:verbose = $true }
    elseif ($low -in '--help', '-help', '-h', '/?') { $doHelp       = $true }
    elseif ($low -eq '--restore') {
        if (($i + 1 -ge $Selection.Count) -or ($Selection[$i + 1] -like '-*')) {
            Write-Err "--restore requires a backup id (see --backup-list)."; exit 1
        }
        $doRestore = $true; $restoreId = $Selection[$i + 1]; $i++
    }
    elseif ($tok -like '--*') {
        # --<plugin> or --<plugin>.config -> a plugin request
        $requested += ($tok -replace '^--', '' -replace '(?i)\.config$', '')
    }
    elseif ($tok -like '-*') { $unknownFlags += $tok }              # unknown single-dash flag
    else   { $requested += ($tok -replace '(?i)\.config$', '') }    # bare plugin name
    $i++
}
#endregion

Write-Host "pwsh-plugins :: addconfig" -ForegroundColor Magenta

#region standalone actions --------------------------------------------------
if ($doHelp) { Show-Usage; exit 0 }

if ($unknownFlags.Count) {
    foreach ($f in $unknownFlags) { Write-Err "unknown flag '$f'" }
    Show-Usage
    exit 1
}

if ($doList) {
    Write-Step "Available plugins"
    $names = Get-PluginNames
    if (-not $names) { Write-Warn "no plugins found under $script:pluginsRoot"; exit 0 }
    $w = ($names | Measure-Object -Property Length -Maximum).Maximum
    foreach ($n in $names) {
        $m = Get-PluginMetadata (Get-PluginConfigPath $n)
        Write-Host ("    {0}  {1}" -f $n.PadRight($w), $m.Description)
    }
    exit 0
}

if ($doBackupList) {
    Write-Step "Profile backups (newest first) for $ProfilePath"
    $baks = Get-ProfileBackups $ProfilePath
    if (-not $baks) { Write-Warn "no backups found"; exit 0 }
    $baks | Select-Object Id, LastWriteTime | Format-Table -AutoSize
    exit 0
}

if ($doRestore) {
    Write-Step "Restoring profile"
    $ok = Restore-ProfileFromBackup $ProfilePath $restoreId
    if ($ok) { exit 0 } else { exit 1 }
}
#endregion

#region resolve selection ---------------------------------------------------
if ($selectAll) {
    $selected = Get-PluginNames
} else {
    $selected = @($requested | Select-Object -Unique)
}

if (-not $selected -or $selected.Count -eq 0) {
    Write-Warn "no plugins selected."
    Show-Usage
    exit 0
}
#endregion

#region install routine -----------------------------------------------------
# All shared state lives in $script:* so the recursive dependency install can
# mutate the single in-memory profile string.
$script:content   = if (Test-Path -LiteralPath $ProfilePath) { (Get-Content -LiteralPath $ProfilePath -Raw) } else { '' }
if ($null -eq $script:content) { $script:content = '' }
$script:changed   = $false
$script:failed    = $false                    # a requested plugin failed validation
$script:visited   = @()                       # names handled this run (dedupe + cycle guard)
$script:planned   = @($selected)              # user's explicit selection (skip prompting for these)

function Install-Plugin ([string] $Name) {
    if ($script:visited -contains $Name) { return }   # already handled (cycle/dupe guard)
    $script:visited += $Name

    # 1. Validate the config + header.
    $cfg = Get-PluginConfigPath $Name
    if (-not (Test-Path -LiteralPath $cfg)) {
        Write-Err "unknown plugin '$Name' (config not found: $cfg)"
        Write-Host "    available: $((Get-PluginNames) -join ', ')" -ForegroundColor DarkGray
        $script:failed = $true
        return
    }
    Write-Note "resolved $Name -> $cfg"
    $meta = Get-PluginMetadata $cfg
    if (-not $meta.Name -or -not $meta.Version) {
        Write-Err "'$Name' has an invalid metadata header (missing Plugin/Version). Skipping."
        $script:failed = $true
        return
    }
    $ver  = $meta.Version
    $cost = if ($meta.StartupCost) { $meta.StartupCost } else { 'n/a' }

    # 2. Idempotency (checked against the evolving in-memory profile).
    $already = Test-PluginInstalled $script:content $Name
    if ($already -and -not $script:force) {
        Write-Warn "$Name already installed — use --force to reinstall. Skipping."
        return
    }

    # 3. Plugin dependencies.
    foreach ($dep in (Get-ListValues $meta.Dependencies)) {
        if (Test-PluginInstalled $script:content $dep) { continue }   # already in profile
        if ($script:visited -contains $dep) { continue }              # already handled this run
        if ($script:planned -contains $dep) { continue }              # user already queued it
        Write-Warn "'$Name' depends on plugin '$dep', which isn't installed."
        $ans = Read-Host "    Install required plugin '$dep'? (y/N)"
        if ($ans -match '^\s*(y|yes)\s*$') { Install-Plugin $dep }
        else { Write-Warn "continuing without '$dep' — '$Name' may not work as intended." }
    }

    # 4. External tool requirements (cmd|winget-id).
    foreach ($req in (Get-ListValues $meta.Requires)) {
        $parts    = $req.Split('|', 2)
        $cmd      = $parts[0].Trim()
        $wingetId = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }
        if (Get-Command $cmd -ErrorAction SilentlyContinue) { continue }
        Write-Warn "'$Name' requires external tool '$cmd', which isn't on PATH."
        if (-not $wingetId) { Write-Warn "install '$cmd' manually, then reload your profile."; continue }
        $ans = Read-Host "    Install '$cmd' via 'winget install --id $wingetId -e'? (y/N)"
        if ($ans -notmatch '^\s*(y|yes)\s*$') {
            Write-Warn "continuing without '$cmd' — '$Name' won't work until it's installed."
            continue
        }
        if ($script:whatIf) {
            Write-Host "    [dry-run] would run: winget install --id $wingetId -e" -ForegroundColor DarkGray
        } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
            try { winget install --id $wingetId -e } catch { Write-Warn "winget failed: $($_.Exception.Message)" }
        } else {
            Write-Warn "winget not found — install '$cmd' manually ($wingetId)."
        }
    }

    # 5. Inject (or, under -WhatIf, just report).
    if ($script:whatIf) {
        $verb = if ($already) { 'reinstall' } else { 'install' }
        Write-Host "    [dry-run] would $verb $Name (v$ver) — startup cost $cost" -ForegroundColor DarkGray
        $script:changed = $true
        return
    }
    if ($already) { $script:content = Remove-PluginBlock $script:content $Name }   # force: drop the old block first
    $block = New-PluginBlock $cfg $Name $ver
    $body  = $script:content.TrimEnd()
    $script:content = if ($body.Length -gt 0) { "$body`r`n`r`n$block`r`n" } else { "$block`r`n" }
    $script:changed = $true
    Write-Ok "installed $Name (v$ver) — startup cost $cost"
}

Write-Step "Installing selected plugins into $ProfilePath"
foreach ($n in $selected) { Install-Plugin $n }
#endregion

#region write ---------------------------------------------------------------
if (-not $script:changed) {
    Write-Host "`nNothing changed." -ForegroundColor DarkGray
    if ($script:failed) { exit 1 } else { exit 0 }
}

if ($script:whatIf) {
    Write-Host "`n[dry-run] no files were modified." -ForegroundColor Cyan
    exit 0
}

# One backup of the original, then one write for the whole batch.
$bak = Backup-Profile $ProfilePath
if ($bak) { Write-Ok "backed up profile -> $(Split-Path $bak -Leaf)" }
$dir = Split-Path -Parent $ProfilePath
if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
Set-Content -LiteralPath $ProfilePath -Value ($script:content.TrimEnd()) -Encoding utf8

Write-Host "`nRestart your terminal (or run '. `$PROFILE.CurrentUserAllHosts') to apply." -ForegroundColor Cyan
if ($bak) { Write-Host "Undo with:  .\addconfig.ps1 --restore $($bak -replace '.*\.pwsh-plugins-bak\.', '')" -ForegroundColor DarkGray }
#endregion
