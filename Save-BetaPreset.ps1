# Run after /ztf savepreset and /reload (or logout). Never changes your WTF files.
[CmdletBinding()]
param(
    [string]$GamePath,
    [string]$Account,
    [string]$SavedFile,
    [string]$OutputFolder
)
$ErrorActionPreference = 'Stop'
if (-not $SavedFile -or -not $OutputFolder) {
    if (-not $GamePath) {
        $candidate = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        if (Test-Path -LiteralPath (Join-Path $candidate 'WTF\Account')) { $GamePath = $candidate }
        else { $GamePath = Read-Host 'Full path to your WoW _classic_beta_ folder' }
    }
    $GamePath = (Resolve-Path -LiteralPath $GamePath).Path
}
if (-not $SavedFile) {
    $accountsRoot = Join-Path $GamePath 'WTF\Account'
    $accounts = @(Get-ChildItem -LiteralPath $accountsRoot -Directory | Where-Object {
        (Test-Path -LiteralPath (Join-Path $_.FullName 'SavedVariables\ZoidsTools_F_Recovery.lua')) -or
        (Test-Path -LiteralPath (Join-Path $_.FullName 'SavedVariables\ZoidsTools_F.lua'))
    })
    if (-not $Account) {
        if ($accounts.Count -eq 1) { $Account = $accounts[0].Name }
        elseif ($accounts.Count -eq 0) { throw 'No ZoidsTools saved files found. Save a preset in game, then reload first.' }
        else {
            Write-Host ('Accounts: ' + (($accounts | ForEach-Object Name) -join ', '))
            $Account = Read-Host 'Account folder name to use'
        }
    }
    $selected = @($accounts | Where-Object Name -eq $Account)
    if ($selected.Count -ne 1) { throw 'Choose an account from the listed saved accounts.' }
    $savedRoot = Join-Path $selected[0].FullName 'SavedVariables'
    # Prefer the main explicit preset, then the independent companion copy.
    foreach ($name in @('ZoidsTools_F.lua', 'ZoidsTools_F_Recovery.lua')) {
        $path = Join-Path $savedRoot $name
        if (Test-Path -LiteralPath $path) {
            $contents = [IO.File]::ReadAllText($path)
            if ($contents -match '(?m)^ZoidsTools_F(?:Recovery)?PresetDB\s*=\s*\{\s*\[') {
                $SavedFile = $path
                break
            }
        }
    }
    if (-not $SavedFile) { throw 'No explicitly saved preset found. Use /ztf savepreset, then /reload. Existing fallback was not changed.' }
}
$contents = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $SavedFile).Path)
if ($contents -notmatch '(?m)^ZoidsTools_F(?:Recovery)?PresetDB\s*=\s*\{\s*\[') {
    throw 'This file has no nonempty explicit preset. Existing fallback was not changed.'
}
if (-not $OutputFolder) { $OutputFolder = Join-Path $GamePath 'Interface\AddOns\ZoidsTools_F_Preset' }
$OutputFolder = [IO.Path]::GetFullPath($OutputFolder)
if ((Split-Path $OutputFolder -Leaf) -ne 'ZoidsTools_F_Preset') { throw 'Output folder must be named ZoidsTools_F_Preset.' }
$tocText = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'ZoidsTools_F.toc'))
$version = [regex]::Match($tocText, '(?m)^## Version:\s*(\S+)').Groups[1].Value
$interface = [regex]::Match($tocText, '(?m)^## Interface:\s*([^\r\n]+)').Groups[1].Value
if (-not $version -or -not $interface) { throw 'Main addon manifest is missing version information.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
$presetPath = Join-Path $OutputFolder 'Preset.lua'
$tocPath = Join-Path $OutputFolder 'ZoidsTools_F_Preset.toc'
foreach ($path in @($presetPath, $tocPath)) {
    if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination ($path + '.' + (Get-Date -Format 'yyyyMMddHHmmssfff') + '.bak') }
}
# SavedVariables are Lua assignments; keep their tables local so the fallback
# does not replace a normally loaded main save. Only expose the chosen preset.
$lua = "-- Private generated preset. Do not publish this file.`nlocal ZoidsTools_FDB, ZoidsTools_FBackupDB, ZoidsTools_FPresetDB, ZoidsTools_FInventoryDB`nlocal ZoidsTools_FRecoveryDB, ZoidsTools_FRecoveryPresetDB`n" + $contents + "`nZoidsTools_FRecovery = ZoidsTools_FPresetDB or ZoidsTools_FRecoveryPresetDB`n"
[IO.File]::WriteAllText($presetPath, $lua, $utf8)
[IO.File]::WriteAllText($tocPath, "## Interface: $interface`n## Title: ZoidsTools Forever Personal Preset`n## Notes: Private beta fallback created from your saved preset.`n## Version: $version`n`nPreset.lua`n", $utf8)
Write-Host "Created your private fallback in $OutputFolder"
Write-Host 'Fully restart WoW after first installation and keep Personal Preset enabled. Use /ztf restorepreset if needed.'
Write-Host 'To update it: save a new preset in game, reload, then run this helper again before restoring the old preset.'
