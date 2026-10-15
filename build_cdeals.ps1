# Сделки конкурентов (лист «Сделки» книги конкурентов, ответ values.get) -> cdeals.js.
# Берутся только поля для анализа: проект, дата договора, комнатность, площадь, бюджет, ипотека, тип договора и продавца, этаж.
# Наши проекты из этого листа не берутся: наши сделки идут из таблицы «Сделки — сводная».
param(
  [string]$src = 'C:\Users\baza\konkurentny-srez\raw\cdeals.json',
  [string]$out = 'C:\Users\baza\konkurentny-srez\cdeals.js'
)
$u = New-Object System.Text.UTF8Encoding($false)
$v = (Get-Content -Raw -Encoding UTF8 $src | ConvertFrom-Json).values
$OWN = @('Алиса', 'Милый дом (BAZA)', 'ДНК: Дом на Куйбышева')

function Num($s) {
  if ($null -eq $s) { return $null }
  $t = ([string]$s -replace '[\s\u00A0\u202F%]', '') -replace ',', '.'
  if ($t -eq '') { return $null }
  $n = 0.0
  if ([double]::TryParse($t, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { return $n }
  return $null
}
$H = @{}
for ($i = 0; $i -lt $v[0].Count; $i++) { $H[([string]$v[0][$i]).Trim()] = $i }
function C($r, $name) { if (-not $H.ContainsKey($name)) { return '' }; $i = $H[$name]; if ($i -lt $r.Count) { return ([string]$r[$i]).Trim() } return '' }
foreach ($need in 'Проект', 'Количество комнат (Данные Объектива)', 'Площадь, м² (Сводная)', 'Расчетный бюджет лота, ₽', 'Дата договора', 'Тип обременения') {
  if (-not $H.ContainsKey($need)) { throw "В листе сделок нет столбца «$need»" }
}

$dicts = [ordered]@{ p = (New-Object System.Collections.ArrayList); ct = (New-Object System.Collections.ArrayList); sl = (New-Object System.Collections.ArrayList) }
$maps = @{ p = @{}; ct = @{}; sl = @{} }
function Idx($k, $val) { if (-not $maps[$k].ContainsKey($val)) { $maps[$k][$val] = $dicts[$k].Count; [void]$dicts[$k].Add($val) }; return $maps[$k][$val] }

$rows = New-Object System.Collections.ArrayList
foreach ($r in ($v | Select-Object -Skip 1)) {
  $p = C $r 'Проект'
  if (-not $p -or $OWN -contains $p) { continue }
  $vid = C $r 'Вид помещения'; if ($vid -and $vid -ne 'квартира') { continue }
  $area = Num (C $r 'Площадь, м² (Сводная)'); $budget = Num (C $r 'Расчетный бюджет лота, ₽')
  $d = C $r 'Дата договора'
  if (-not $area -or -not $budget -or $d -notmatch '^(\d{1,2})\.(\d{1,2})\.(\d{4})$') { continue }
  $date = '{0}-{1:D2}-{2:D2}' -f $Matches[3], [int]$Matches[2], [int]$Matches[1]
  $mort = if ((C $r 'Тип обременения') -match 'потек') { 1 } else { 0 }
  $o = New-Object System.Collections.ArrayList
  [void]$o.Add((Idx 'p' $p)); [void]$o.Add($date); [void]$o.Add((C $r 'Количество комнат (Данные Объектива)').ToLower())
  [void]$o.Add($area); [void]$o.Add($budget); [void]$o.Add($mort)
  [void]$o.Add((Idx 'ct' (C $r 'Тип договора'))); [void]$o.Add((Idx 'sl' (C $r 'Тип продавца'))); [void]$o.Add((Num (C $r 'Этаж')))
  [void]$rows.Add($o)
}
if ($rows.Count -lt 100) { throw "Сделок конкурентов слишком мало: $($rows.Count)" }
$obj = [ordered]@{ cols = @('p', 'date', 'rooms', 'area', 'budget', 'mort', 'ct', 'sl', 'floor'); dicts = $dicts; rows = $rows }
[IO.File]::WriteAllText($out, 'window.CDEALS = ' + ($obj | ConvertTo-Json -Depth 5 -Compress) + ';', $u)
"cdeals: $($rows.Count); bytes: $((Get-Item $out).Length)"
