# Сделки (таблица «Сделки — сводная (Бестселлер, Алиса, ДМД2)», лист «Все сделки») -> deals.js.
# Клиенты и комментарии не сохраняются.
param(
  [string]$src = 'C:\Users\baza\.claude\projects\C--Users-baza\4a25521a-e033-4797-9086-8b53ee977344\tool-results\mcp-claude_ai_Google_Sheets-get_spreadsheet-1791802063347.txt',
  [string]$out = 'C:\Users\baza\konkurentny-srez\deals.js'
)
$j = Get-Content -Raw -Encoding UTF8 $src | ConvertFrom-Json
$rows = $j.sheets[0].data[0].rowData

function Num($s) {
  if ($null -eq $s) { return $null }
  $t = ([string]$s -replace '[\s\u00A0\u202F%]', '') -replace ',', '.' -replace '−', '-'
  if ($t -eq '') { return $null }
  $n = 0.0
  if ([double]::TryParse($t, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { return $n }
  return $null
}
function Cell($r, $i) { if ($r.values -and $r.values.Count -gt $i) { return ([string]$r.values[$i].formattedValue).Trim() } return '' }

# столбцы по заголовкам первой строки
$H = @{}
$hdr = $rows[0].values
for ($i = 0; $i -lt $hdr.Count; $i++) { $H[([string]$hdr[$i].formattedValue).Trim()] = $i }
function C($r, $name) { if ($H.ContainsKey($name)) { return Cell $r $H[$name] } return '' }

$deals = New-Object System.Collections.ArrayList
foreach ($r in ($rows | Select-Object -Skip 1)) {
  $obj = C $r 'ЖК'
  if (-not $obj) { continue }
  $list = Num (C $r 'Цена по прайсу, руб'); $price = Num (C $r 'Цена в договоре, руб')
  if (-not $price) { continue }
  $month = ''; $mm = C $r 'Отчётный месяц'
  if ($mm -match '^(\d{1,2})\.(\d{4})$') { $month = '{0}-{1:D2}' -f $Matches[2], [int]$Matches[1] }
  $date = ''; $dd = C $r 'Дата договора'
  if ($dd -match '^(\d{1,2})\.(\d{1,2})\.(\d{4})$') { $date = '{0}-{1:D2}-{2:D2}' -f $Matches[3], [int]$Matches[2], [int]$Matches[1] }
  if (-not $month -and $date) { $month = $date.Substring(0, 7) }
  $pct = Num (C $r 'Скидка (-) / наценка (+), %'); if ($null -ne $pct) { $pct = $pct / 100 }
  $pv = Num (C $r 'ПВ по ипотеке, %'); if ($null -ne $pv) { $pv = $pv / 100 }
  $av = Num (C $r 'АВ, руб')
  $floor = Num (C $r 'Этаж')
  $o = [ordered]@{
    idx = $deals.Count; obj = $obj; month = $month; date = $date; mgr = (C $r 'Менеджер')
    sec = (C $r 'Секция / подъезд'); floor = $floor; apt = (C $r '№ кв.'); rooms = (C $r 'Комнат').ToLower()
    area = Num (C $r 'Площадь с коэф. 0,3/0,5, м2'); area1 = Num (C $r 'Площадь с коэф. 1, м2'); plan = (C $r 'Планировка')
    list = $list; price = $price; ppm = Num (C $r 'Цена м2, руб')
    finish = (C $r 'Отделка'); finishDesc = (C $r 'Вид отделки'); finishCost = Num (C $r 'Стоимость отделки, руб')
    discPct = $pct; disc = $(if ($null -ne $pct -and $list) { [math]::Round($list * $pct) } else { 0 }); discFmt = (C $r 'Формат скидки/наценки')
    pay = (C $r 'Тип оплаты'); payHow = (C $r 'Способ покупки'); bank = (C $r 'Банк'); pv = $pv
    rate = (C $r 'Ставка, %'); term = (C $r 'Срок кредита, лет'); matcap = Num (C $r 'Маткапитал')
    dealType = (C $r 'Тип сделки'); agent = ((C $r 'Агент') -replace '\s+', ' ').Trim(); avRub = $av
    avPct = $(if ($av -and $price) { $av / $price } else { $null })
  }
  [void]$deals.Add($o)
}
$json = $deals | ConvertTo-Json -Depth 3 -Compress
if ($deals.Count -eq 1) { $json = "[$json]" }
[IO.File]::WriteAllText($out, "window.DEALS = $json;", (New-Object System.Text.UTF8Encoding($false)))
"deals: $($deals.Count); bytes: $((Get-Item $out).Length)"
