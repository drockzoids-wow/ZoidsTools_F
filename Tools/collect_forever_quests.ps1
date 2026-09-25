# Collect public Wowhead Forever list data outside the game. Never execute page scripts.
param([string]$OutputDirectory = (Join-Path $PSScriptRoot '../build/quest-refresh'), [switch]$Resume)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$all = @{}
$log = [System.Collections.Generic.List[object]]::new()
function Read-QuestData([string]$html) {
    $match = [regex]::Match($html, "new Listview\(\{template: 'quest'.*?data:\s*(\[)", 'Singleline')
    if (!$match.Success) {
        if ($html.Contains('Your criteria did not match any quests.')) { return ,@() }
        throw 'Quest list missing; refusing to treat a failed response as an empty list'
    }
    $start = $match.Groups[1].Index
    $depth = 0; $quoted = $false; $escaped = $false
    for ($i = $start; $i -lt $html.Length; $i++) {
        $c = $html[$i]
        if ($quoted) {
            if ($escaped) { $escaped = $false }
            elseif ($c -eq '\') { $escaped = $true }
            elseif ($c -eq '"') { $quoted = $false }
        } elseif ($c -eq '"') { $quoted = $true }
        elseif ($c -eq '[') { $depth++ }
        elseif ($c -eq ']') {
            $depth--
            if ($depth -eq 0) { return ,@($html.Substring($start, $i-$start+1) | ConvertFrom-Json) }
        }
    }
    throw 'Unterminated quest data'
}
function Fetch([string]$suffix, [string]$name) {
    $url = "https://www.wowhead.com/forever/quests$suffix"
    $file = Join-Path $OutputDirectory "$name.html"
    if (!$Resume -or !(Test-Path -LiteralPath $file)) {
        Invoke-WebRequest -Uri $url -OutFile $file
        Start-Sleep -Milliseconds 300
    }
    return Get-Content -LiteralPath $file -Raw
}
function Collect([int]$lo, [int]$hi, [int]$reqlo = -1, [int]$reqhi = 255) {
    $suffix = "/min-level:$lo/max-level:$hi"
    $name = "level-$lo-$hi"
    if ($reqlo -ge 0) { $suffix += "/min-req-level:$reqlo/max-req-level:$reqhi"; $name += "-req-$reqlo-$reqhi" }
    $html = Fetch $suffix $name
    $rows = Read-QuestData $html
    $truncated = $html -match '_truncated:\s*1'
    $log.Add([pscustomobject]@{url="https://www.wowhead.com/forever/quests$suffix";count=$rows.Count;truncated=$truncated})
    Write-Host "$name : $($rows.Count); truncated=$truncated"
    if ($truncated -and $lo -lt $hi) {
        $mid = [int][Math]::Floor(($lo+$hi)/2)
        Collect $lo $mid; Collect ($mid+1) $hi
    } elseif ($truncated -and $reqlo -lt 0) {
        Collect $lo $hi 0 59; Collect $lo $hi 60 255
    } elseif ($truncated -and $reqlo -lt $reqhi) {
        $mid = [int][Math]::Floor(($reqlo+$reqhi)/2)
        Collect $lo $hi $reqlo $mid; Collect $lo $hi ($mid+1) $reqhi
    } elseif ($truncated) { throw "Unresolved truncation in $name" }
    else {
        foreach ($q in $rows) {
            if ($q.id -le 0 -or !$q.name) { throw 'Invalid quest record' }
            if ($q.level -lt $lo -or $q.level -gt $hi) { throw "Level filter ignored in $name" }
            if ($reqlo -ge 0 -and ($q.reqlevel -lt $reqlo -or $q.reqlevel -gt $reqhi)) { throw "Required-level filter ignored in $name" }
            $all[[string]$q.id] = $q
        }
    }
}
$rootHtml = Fetch '' 'quests'
$totalMatch = [regex]::Match($rootHtml, '([\d,]+) quests found')
if (!$totalMatch.Success) { throw 'Cannot establish reported inventory size' }
$reported = [int]$totalMatch.Groups[1].Value.Replace(',', '')
Collect -10 59
Collect 60 255
$all.Values | Sort-Object id | ConvertTo-Json -Depth 30 | Set-Content (Join-Path $OutputDirectory 'quests-raw.json') -Encoding utf8
[pscustomobject]@{checked=(Get-Date -Format 'yyyy-MM-dd');reportedTotal=$reported;uniqueCount=$all.Count;requests=$log} |
    ConvertTo-Json -Depth 10 | Set-Content (Join-Path $OutputDirectory 'collection-log.json') -Encoding utf8
if ($all.Count -ne $reported) { throw "Collected $($all.Count) unique IDs but root reports $reported; inspect coverage before importing" }
Write-Host "Verified $($all.Count) unique quests against reported total."
