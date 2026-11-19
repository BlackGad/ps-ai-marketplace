param([string]$Model, [string[]]$Arguments)

if (@($Arguments | Where-Object { $_ -match '^(--model|-m)(=|$)' }).Count) { return }
'--model'
$Model
