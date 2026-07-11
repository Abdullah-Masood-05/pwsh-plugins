<#
.SYNOPSIS
    Lists available pwsh-plugins and whether each is installed.

.DESCRIPTION
    Scans .\plugins\<name>\<name>.config for plugin metadata and reports it as
    an aligned table. The "Installed" column is derived from the marker blocks
    in $PROFILE.CurrentUserAllHosts (or a -ProfilePath override).

    Use --info <name> for a full metadata dump plus the plugin's README intro.

.PARAMETER Selection
    All remaining tokens: mode / flags (case-insensitive):
      (none) / --available   list every available plugin (default)
      --installed            list only plugins present in the profile
      --info <name>          detailed view of a single plugin
      --help / -h            show usage and exit

.PARAMETER ProfilePath
    Target profile file. Defaults to $PROFILE.CurrentUserAllHosts.

.EXAMPLE
    .\listconfigs.ps1

.EXAMPLE
    .\listconfigs.ps1 --installed

.EXAMPLE
    .\listconfigs.ps1 --info zoxide
#>
# All tokens (mode/flags and -ProfilePath <path>) arrive via the automatic $args and are
# parsed by hand below. We deliberately declare NO parameters:
#   * a [Parameter(ValueFromRemainingArguments)] param would make this an advanced
#     function whose common params (-InformationAction, -Verbose, ...) would swallow
#     --info / --installed; and
#   * even a plain [string] $ProfilePath param would bind the first --flag positionally.
$Selection = $args
$ProfilePath = $null

$ErrorActionPreference = 'Stop'

#region helpers -------------------------------------------------------------
function Write-Step ($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok   ($m) { Write-Host "    [ok] $m" -ForegroundColor Green }
function Write-Warn ($m) { Write-Host "    [!]  $m" -ForegroundColor Yellow }
function Write-Err  ($m) { Write-Host "    [x]  $m" -ForegroundColor Red }

function Get-PluginConfigPath ([string] $Name) {
    Join-Path (Join-Path $script:pluginsRoot $Name) "$Name.config"
}

function Get-PluginNames {
    if (-not (Test-Path -LiteralPath $script:pluginsRoot)) { return @() }
    Get-ChildItem -LiteralPath $script:pluginsRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "$($_.Name).config") } |
        Select-Object -ExpandProperty Name | Sort-Object
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
        Description  = $meta['Description']
        Author       = $meta['Author']
        Version      = $meta['Version']
        Dependencies = $meta['Dependencies']
        Requires     = $meta['Requires']
        StartupCost  = $meta['Startup Cost']
        Raw          = $meta
    }
}

function Test-PluginInstalled ([string] $Content, [string] $Name) {
    if (-not $Content) { return $false }
    [regex]::IsMatch($Content, '(?m)^[ \t]*#\s*>>>\s*pwsh-plugins:' + [regex]::Escape($Name) + '[ \t]')
}

# Version recorded in the installed marker, or $null if absent.
function Get-InstalledVersion ([string] $Content, [string] $Name) {
    if (-not $Content) { return $null }
    $m = [regex]::Match($Content, '(?m)^[ \t]*#\s*>>>\s*pwsh-plugins:' + [regex]::Escape($Name) + '[ \t]+\(v([^)]*)\)')
    if ($m.Success) { $m.Groups[1].Value } else { $null }
}

# First real paragraph of a README (skips leading blank lines and # headings).
function Get-ReadmeIntro ([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $raw = (Get-Content -LiteralPath $Path -Raw)
    if (-not $raw) { return $null }
    $blocks = [regex]::Split($raw.Trim(), '(?:\r?\n)\s*(?:\r?\n)+') | Where-Object { $_.Trim() }
    $intro = $blocks | Where-Object { $_.TrimStart() -notmatch '^#' } | Select-Object -First 1
    if (-not $intro) { $intro = $blocks | Select-Object -First 1 }
    if ($intro) { ($intro -replace '\s*\r?\n\s*', ' ').Trim() } else { $null }
}

function Show-Usage {
    Write-Host @"
Usage: .\listconfigs.ps1 [--available | --installed | --info <name>]

  (no args) / --available   list all available plugins (default)
  --installed               list only plugins present in the profile
  --info <name>             full details for a single plugin
  --help, -h                show this help
  -ProfilePath <path>       read a specific profile file
"@ -ForegroundColor Gray
}
#endregion

#region argument parsing ----------------------------------------------------
$script:pluginsRoot = Join-Path $PSScriptRoot 'plugins'
if (-not $Selection) { $Selection = @() }

$mode      = 'available'   # available | installed | info
$infoName  = $null
$doHelp    = $false
$unknown   = @()

$i = 0
while ($i -lt $Selection.Count) {
    $tok = $Selection[$i]
    $low = "$tok".ToLowerInvariant()
    if     ($low -eq '--available')                 { $mode = 'available' }
    elseif ($low -eq '--installed')                 { $mode = 'installed' }
    elseif ($low -in '--help', '-help', '-h', '/?') { $doHelp = $true }
    elseif ($low -in '-profilepath', '--profilepath', '--profile-path') {
        if ($i + 1 -ge $Selection.Count) { Write-Err "-ProfilePath requires a path."; exit 1 }
        $ProfilePath = $Selection[$i + 1]; $i++
    }
    elseif ($low -eq '--info') {
        if (($i + 1 -ge $Selection.Count) -or ($Selection[$i + 1] -like '-*')) {
            Write-Err "--info requires a plugin name."; exit 1
        }
        $mode = 'info'; $infoName = ($Selection[$i + 1] -replace '(?i)\.config$', ''); $i++
    }
    else { $unknown += $tok }
    $i++
}
if (-not $ProfilePath) { $ProfilePath = $PROFILE.CurrentUserAllHosts }
#endregion

Write-Host "pwsh-plugins :: listconfigs" -ForegroundColor Magenta

if ($doHelp) { Show-Usage; exit 0 }

if ($unknown.Count) {
    foreach ($u in $unknown) { Write-Err "unexpected argument '$u'" }
    Show-Usage
    exit 1
}

# Read the profile once for install-state lookups.
$content = if (Test-Path -LiteralPath $ProfilePath) { (Get-Content -LiteralPath $ProfilePath -Raw) } else { '' }
if ($null -eq $content) { $content = '' }

$names = Get-PluginNames
if (-not $names) { Write-Warn "no plugins found under $script:pluginsRoot"; exit 0 }

#region --info --------------------------------------------------------------
if ($mode -eq 'info') {
    $cfg = Get-PluginConfigPath $infoName
    if (-not (Test-Path -LiteralPath $cfg)) {
        Write-Err "unknown plugin '$infoName' (config not found: $cfg)"
        Write-Host "    available: $($names -join ', ')" -ForegroundColor DarkGray
        exit 1
    }
    $m = Get-PluginMetadata $cfg
    Write-Step "$infoName"
    foreach ($k in $m.Raw.Keys) {
        Write-Host ("    {0}  {1}" -f "$($k):".PadRight(15), $m.Raw[$k])
    }

    $ver = Get-InstalledVersion $content $infoName
    if ($ver) { Write-Host "    Installed:       yes (v$ver)" -ForegroundColor Green }
    else      { Write-Host "    Installed:       no" -ForegroundColor DarkGray }
    Write-Host "    Config path:     $cfg"

    $intro = Get-ReadmeIntro (Join-Path (Split-Path -Parent $cfg) 'README.md')
    if ($intro) {
        Write-Host "`n    README:" -ForegroundColor Cyan
        Write-Host "    $intro"
    }
    exit 0
}
#endregion

#region table (available / installed) ---------------------------------------
$tick = [char]0x2713   # check mark
$dot  = [char]0x00B7   # middle dot

$rows = foreach ($n in $names) {
    $m         = Get-PluginMetadata (Get-PluginConfigPath $n)
    $isInstall = Test-PluginInstalled $content $n
    if ($mode -eq 'installed' -and -not $isInstall) { continue }
    [pscustomobject]@{
        Name         = $n
        Version      = $m.Version
        Startup      = $m.StartupCost
        Dependencies = if ($m.Dependencies) { $m.Dependencies } else { 'None' }
        Installed    = if ($isInstall) { "$tick" } else { "$dot" }
    }
}

if ($mode -eq 'installed') { Write-Step "Installed plugins ($ProfilePath)" }
else                       { Write-Step "Available plugins" }

if (-not $rows) {
    Write-Warn "none"
    exit 0
}
$rows | Format-Table -AutoSize
#endregion
