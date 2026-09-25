# Fetch the complete linked index and details only for IDs absent from the union.
param([string]$OutputDirectory = (Join-Path $PSScriptRoot '../build/quest-refresh'), [switch]$Resume)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$file = Join-Path $OutputDirectory '60tools.html'
if (!$Resume -or !(Test-Path -LiteralPath $file)) {
    Invoke-WebRequest 'https://www.60.tools/quests' -OutFile $file
}
$known = @{}
Get-Content (Join-Path $OutputDirectory 'quests-raw.json') -Raw | ConvertFrom-Json | ForEach-Object { $known[[string]$_.id] = $true }
$data = Get-Content (Join-Path $PSScriptRoot '../Completionist/Data.lua') -Raw
[regex]::Matches($data, '(?m)(?:^\{|id=)(\d+),') | ForEach-Object { $known[$_.Groups[1].Value] = $true }
$html = Get-Content -LiteralPath $file -Raw
$links = @{}
[regex]::Matches($html, 'href="(/quests/(\d+)[^"]*)"') | ForEach-Object { $links[$_.Groups[2].Value] = $_.Groups[1].Value }
$total = [int]([regex]::Match($html, '([\d,]+)<!-- --> records').Groups[1].Value.Replace(',', ''))
if (!$total -or $links.Count -ne $total) { throw 'Secondary full-index count mismatch' }
foreach ($id in $links.Keys) {
    if ($known.ContainsKey($id)) { continue }
    $detail = Join-Path $OutputDirectory "60tools-detail-$id.html"
    if (!$Resume -or !(Test-Path -LiteralPath $detail)) {
        Invoke-WebRequest ("https://www.60.tools" + $links[$id]) -OutFile $detail
        Start-Sleep -Milliseconds 300
    }
}
Write-Host "Checked $($links.Count) secondary index IDs; extra quest detail pages cached for import."
