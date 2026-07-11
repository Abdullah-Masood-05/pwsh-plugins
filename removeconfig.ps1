<#
.SYNOPSIS
    Removes pwsh-plugins snippets from your PowerShell profile.

.DESCRIPTION
    Deletes the labelled marker block(s) that addconfig.ps1 injected into
    $PROFILE.CurrentUserAllHosts (or a -ProfilePath override). The profile is
    backed up before any change, so a removal can be undone with:
        .\addconfig.ps1 --restore <id>

    Choose plugins with --<name> flags (bare <name> also works) or --all to
    remove every installed pwsh-plugins block.

.PARAMETER Selection
    All remaining tokens: plugin names / flags. Recognised flags (case-insensitive):
      --all              remove every installed pwsh-plugins block
      --whatif  / -WhatIf   dry run: list what would be removed, change nothing
      --force   / -Force    accepted for symmetry (removal always proceeds)
      --verbose / -Verbose  extra logging
      --help    / -h     show usage and exit
      --<name>[.config]  a plugin to remove (also accepts a bare <name>)

.PARAMETER ProfilePath
    Target profile file. Defaults to $PROFILE.CurrentUserAllHosts.

.EXAMPLE
    .\removeconfig.ps1 --zoxide

.EXAMPLE
    .\removeconfig.ps1 --all --whatif
#>
# All tokens (plugin names, --flags, and -ProfilePath <path>) arrive via the automatic
# $args and are parsed by hand below. We deliberately declare NO parameters:
#   * a [Parameter(ValueFromRemainingArguments)] param would make this an advanced
#     function whose common params (-Verbose, -InformationAction, ...) would swallow
#     --verbose / --info; and
#   * even a plain [string] $ProfilePath param would bind the first --plugin token as a
#     positional value.
$Selection = $args
$ProfilePath = $null

$ErrorActionPreference = 'Stop'

#region helpers -------------------------------------------------------------
function Write-Step ($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok   ($m) { Write-Host "    [ok] $m" -ForegroundColor Green }
function Write-Warn ($m) { Write-Host "    [!]  $m" -ForegroundColor Yellow }
function Write-Err  ($m) { Write-Host "    [x]  $m" -ForegroundColor Red }
function Write-Note ($m) { if ($script:verbose) { Write-Host "    [v]  $m" -ForegroundColor DarkGray } }

function Get-PluginConfigPath ([string] $Name) {
    Join-Path (Join-Path $script:pluginsRoot $Name) "$Name.config"
}

function Get-PluginMetadata ([string] $ConfigPath) {
    $lines = Get-Content -LiteralPath $ConfigPath
    $meta = [ordered]@{}
    foreach ($line in $lines) {
        if ($line -match '^#\s*([^:]+):\s*(.*)$') { $meta[$Matches[1].Trim()] = $Matches[2].Trim() }
        else { break }
    }
    [pscustomobject]@{
        Name         = $meta['Plugin']
        Version      = $meta['Version']
        Dependencies = $meta['Dependencies']
    }
}

function Get-ListValues ($value) {
    if (-not $value) { return @() }
    $v = "$value".Trim()
    if ($v -eq '' -or $v -ieq 'None') { return @() }
    @($v.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Test-PluginInstalled ([string] $Content, [string] $Name) {
    if (-not $Content) { return $false }
    [regex]::IsMatch($Content, '(?m)^[ \t]*#\s*>>>\s*pwsh-plugins:' + [regex]::Escape($Name) + '[ \t]')
}

# Every installed block, as { Name, Version }, in file order.
function Get-InstalledPlugins ([string] $Content) {
    if (-not $Content) { return @() }
    $rx = [regex]'(?m)^[ \t]*#\s*>>>\s*pwsh-plugins:(\S+)[ \t]+\(v([^)]*)\)'
    foreach ($m in $rx.Matches($Content)) {
        [pscustomobject]@{ Name = $m.Groups[1].Value; Version = $m.Groups[2].Value }
    }
}

function Remove-PluginBlock ([string] $Content, [string] $Name) {
    $n = [regex]::Escape($Name)
    $open  = '#\s*>>>\s*pwsh-plugins:' + $n + '[ \t]'
    $close = '#\s*<<<\s*pwsh-plugins:' + $n + '[ \t]'
    [regex]::Replace($Content, '(?ms)(?:\r?\n){0,2}^[ \t]*' + $open + '.*?^[ \t]*' + $close + '[^\r\n]*', '')
}

function Backup-Profile ([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    # Millisecond precision + a uniqueness bump so two backups in the same second
    # never share a filename and clobber each other.
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

function Show-Usage {
    Write-Host @"
Usage: .\removeconfig.ps1 [--<plugin> ...] [--all] [options]

  --all                 remove every installed pwsh-plugins block
  --<name>[.config]     remove a plugin (bare <name> also works)
  --whatif,  -WhatIf    dry run (list, change nothing)
  --force,   -Force     accepted for symmetry (removal always proceeds)
  --verbose, -Verbose   extra logging
  --help,    -h         show this help
  -ProfilePath <path>   target a specific profile file

Restore a profile afterwards with:  .\addconfig.ps1 --restore <id>
"@ -ForegroundColor Gray
}
#endregion

#region argument parsing ----------------------------------------------------
$script:pluginsRoot = Join-Path $PSScriptRoot 'plugins'
if (-not $Selection) { $Selection = @() }

$removeAll = $false
$doHelp    = $false
$script:force   = $false
$script:whatIf  = $false
$script:verbose = $false
$requested    = @()
$unknownFlags = @()
$expectProfilePath = $false

foreach ($tok in $Selection) {
    $low = "$tok".ToLowerInvariant()
    if ($expectProfilePath) { $ProfilePath = $tok; $expectProfilePath = $false; continue }
    if     ($low -eq '--all')                       { $removeAll = $true }
    elseif ($low -in '--whatif', '-whatif')         { $script:whatIf  = $true }
    elseif ($low -in '--force', '-force')           { $script:force   = $true }
    elseif ($low -in '--verbose', '-verbose')       { $script:verbose = $true }
    elseif ($low -in '--help', '-help', '-h', '/?') { $doHelp       = $true }
    elseif ($low -in '-profilepath', '--profilepath', '--profile-path') { $expectProfilePath = $true }
    elseif ($tok -like '--*') { $requested += ($tok -replace '^--', '' -replace '(?i)\.config$', '') }
    elseif ($tok -like '-*')  { $unknownFlags += $tok }
    else   { $requested += ($tok -replace '(?i)\.config$', '') }
}
if ($expectProfilePath) { Write-Err "-ProfilePath requires a path."; exit 1 }
if (-not $ProfilePath) { $ProfilePath = $PROFILE.CurrentUserAllHosts }
#endregion

Write-Host "pwsh-plugins :: removeconfig" -ForegroundColor Magenta

if ($doHelp) { Show-Usage; exit 0 }

if ($unknownFlags.Count) {
    foreach ($f in $unknownFlags) { Write-Err "unknown flag '$f'" }
    Show-Usage
    exit 1
}

#region resolve profile + targets -------------------------------------------
$content = if (Test-Path -LiteralPath $ProfilePath) { (Get-Content -LiteralPath $ProfilePath -Raw) } else { '' }
if ($null -eq $content) { $content = '' }

$installed = @(Get-InstalledPlugins $content)
Write-Note "profile: $ProfilePath"
Write-Note "installed blocks: $(($installed.Name) -join ', ')"

if ($removeAll) {
    $targets = @($installed.Name)
} else {
    $requested = @($requested | Select-Object -Unique)
    if (-not $requested -or $requested.Count -eq 0) {
        Write-Warn "no plugins selected."
        Show-Usage
        exit 0
    }
    # Keep only the requested plugins that are actually installed; warn about the rest.
    $targets = @()
    foreach ($r in $requested) {
        if ($installed.Name -contains $r) { $targets += $r }
        else { Write-Warn "'$r' is not installed — nothing to remove." }
    }
}

if (-not $targets -or $targets.Count -eq 0) {
    Write-Host "`nNothing to remove." -ForegroundColor DarkGray
    exit 0
}
#endregion

#region report + dependency check -------------------------------------------
Write-Step "The following plugin block(s) will be removed from $ProfilePath"
foreach ($t in $targets) {
    $ver = ($installed | Where-Object { $_.Name -eq $t } | Select-Object -First 1).Version
    Write-Host ("    - {0} (v{1})" -f $t, $ver)
}

# Warn if a plugin that stays installed depends on one being removed.
$remaining = @($installed.Name | Where-Object { $targets -notcontains $_ })
foreach ($t in $targets) {
    foreach ($other in $remaining) {
        $cfg = Get-PluginConfigPath $other
        if (-not (Test-Path -LiteralPath $cfg)) { continue }
        $deps = Get-ListValues (Get-PluginMetadata $cfg).Dependencies
        if ($deps -contains $t) {
            Write-Warn "'$other' depends on '$t' and will remain installed — it may stop working."
        }
    }
}

if ($script:whatIf) {
    Write-Host "`n[dry-run] no files were modified." -ForegroundColor Cyan
    exit 0
}
#endregion

#region remove + write ------------------------------------------------------
$bak = Backup-Profile $ProfilePath
if ($bak) { Write-Ok "backed up profile -> $(Split-Path $bak -Leaf)" }

Write-Step "Removing"
foreach ($t in $targets) {
    $before = $content
    $content = Remove-PluginBlock $content $t
    if ($content -ne $before) { Write-Ok "removed $t" }
    else { Write-Warn "could not locate a complete block for '$t' (marker may be malformed)." }
}

Set-Content -LiteralPath $ProfilePath -Value ($content.TrimEnd()) -Encoding utf8

Write-Host "`nRestart your terminal (or run '. `$PROFILE.CurrentUserAllHosts') to apply." -ForegroundColor Cyan
if ($bak) { Write-Host "Restore the previous profile with:  .\addconfig.ps1 --restore $($bak -replace '.*\.pwsh-plugins-bak\.', '')" -ForegroundColor DarkGray }
#endregion
