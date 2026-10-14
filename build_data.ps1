# Лоты конкурентов (лист «Конкуренты рабочая», ответ values.get) -> data.js
param(
  [string]$src = 'C:\Users\baza\konkurentny-srez\raw\lots.json',
  [string]$out = 'C:\Users\baza\konkurentny-srez\data.js'
)
$d = Get-Content -Raw -Encoding UTF8 $src | ConvertFrom-Json
$v = $d.values

function Num($s) {
  if ($null -eq $s) { return $null }
  $t = ($s -replace '[\s\u00A0\u202F]', '') -replace ',', '.'
  if ($t -eq '') { return $null }
  $n = 0.0
  if ([double]::TryParse($t, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { return $n }
  return $null
}
function DateIso($s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return '' }
  $p = $s.Trim().Split('.')
  if ($p.Count -ne 3) { return '' }
  $y = [int]$p[2]; if ($y -lt 100) { $y += 2000 }
  return ('{0:D4}-{1:D2}-{2:D2}' -f $y, [int]$p[1], [int]$p[0])
}

# categorical columns -> dictionaries
$catCols = [ordered]@{ p = 0; dev = 1; dis = 3; k = 4; cls = 6; st = 11; fc = 12; fl = 13; at = 32; plan = 8 }
$dicts = @{}
$maps = @{}
foreach ($key in $catCols.Keys) { $dicts[$key] = New-Object System.Collections.ArrayList; $maps[$key] = @{} }

$rows = New-Object System.Collections.ArrayList
foreach ($r in ($v | Select-Object -Skip 1)) {
  if (-not $r -or -not $r[0]) { continue }
  $o = New-Object System.Collections.ArrayList
  foreach ($key in $catCols.Keys) {
    $val = [string]$r[$catCols[$key]]
    if ($key -eq 'plan') { $val = DateIso $val }
    if (-not $maps[$key].ContainsKey($val)) { $maps[$key][$val] = $dicts[$key].Count; [void]$dicts[$key].Add($val) }
    [void]$o.Add($maps[$key][$val])
  }
  $rooms = [string]$r[20]
  $area = Num $r[23]
  $price = Num $r[24]
  $disc = Num $r[31]
  $floor = Num $r[15]
  $ready = Num (($r[10]) -replace '%', '')
  [void]$o.Add($rooms)
  [void]$o.Add($area)
  [void]$o.Add($price)
  [void]$o.Add($disc)
  [void]$o.Add($floor)
  [void]$o.Add($ready)
  [void]$o.Add([string]$r[16])
  [void]$o.Add((DateIso $r[30]))
  [void]$o.Add((DateIso ([string]$r[28]).Trim()))
  [void]$o.Add((DateIso ([string]$r[29]).Trim()))
  [void]$rows.Add($o)
}

$obj = [ordered]@{
  cols = @($catCols.Keys) + @('rooms','area','price','disc','floor','ready','lot','appear','priceSet','actual')
  dicts = $dicts
  rows = $rows
}
$json = $obj | ConvertTo-Json -Depth 5 -Compress
[IO.File]::WriteAllText($out, "window.DATA = $json;", (New-Object System.Text.UTF8Encoding($false)))
"rows: $($rows.Count); bytes: $((Get-Item $out).Length)"
"projects: " + ($dicts['p'] -join ' | ')
"plan dates sample: " + (($dicts['plan'] | Select -First 8) -join ', ')
# which projects have actual date 30.09
$v | Select -Skip 1 | ? { $_[29] -like '30.09*' } | Group-Object { $_[0] } | % { "30.09: $($_.Name) $($_.Count)" }
# null checks
"null area: " + ($rows | ? { $null -eq $_[11] }).Count + "; null disc: " + ($rows | ? { $null -eq $_[13] }).Count
