param([string]$Model, [string[]]$Arguments)

if (@($Arguments | Where-Object { $_ -match '^(--model|-m)(=|$)' }).Count) { return }
for ($i = 0; $i -lt $Arguments.Count; $i++) {
    if ($Arguments[$i] -match '^(--config=|-c=?)model\s*=') { return }
    if ($Arguments[$i] -in @('--config', '-c') -and $i + 1 -lt $Arguments.Count -and $Arguments[$i + 1] -match '^model\s*=') { return }
}
'--model'
$Model
