# Сборка index.html: template.html + data.js (лоты конкурентов) + deals.js (сделки) + ref.js (справочник) + дата сборки
param(
  [string]$dir = 'C:\Users\baza\konkurentny-srez',
  [string]$data = 'C:\Users\baza\konkurentny-srez\data.js',
  [string]$deals = '',
  [string]$ref = '',
  [string]$builtAt = '',
  [string]$cdeals = ''
)
$u = New-Object System.Text.UTF8Encoding($false)
if (-not $deals) { $deals = Join-Path $dir 'deals.js' }
$rd = { param($f) [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8) }
$t = & $rd (Join-Path $dir 'template.html')
$meta = if ($builtAt) { 'window.BUILT_AT = "' + $builtAt + '";' } else { '' }
$refJs = if ($ref -and (Test-Path $ref)) { & $rd $ref } else { '' }
$cdJs = if ($cdeals -and (Test-Path $cdeals)) { & $rd $cdeals } else { 'window.CDEALS = null;' }
$page = $t.Replace('/*__META__*/', $meta).Replace('/*__REF__*/', $refJs).Replace('/*__DATA__*/', (& $rd $data)).Replace('/*__DEALS__*/', (& $rd $deals)).Replace('/*__CDEALS__*/', $cdJs)
$i = $page.IndexOf('</style>') + 8
$full = "<!doctype html>`n<html lang=`"ru`">`n<head>`n<meta charset=`"utf-8`">`n<meta name=`"viewport`" content=`"width=device-width, initial-scale=1, viewport-fit=cover`">`n" + $page.Substring(0, $i) + "`n</head>`n<body>" + $page.Substring($i) + "`n</body>`n</html>`n"
[IO.File]::WriteAllText((Join-Path $dir 'index.html'), $full, $u)
"index.html: $((Get-Item (Join-Path $dir 'index.html')).Length) bytes"