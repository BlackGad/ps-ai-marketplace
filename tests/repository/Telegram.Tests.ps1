$testBase = Split-Path $PSScriptRoot -Parent
$root = Split-Path $testBase -Parent
$skill = Join-Path $root 'plugins/legion/skills/legion-telegram'
$png = Join-Path $skill 'assets/test.png'
Assert-True (Test-Path $png) 'Bundled test image exists'
$bytes = [IO.File]::ReadAllBytes($png)
Assert-Equal '89504E470D0A1A0A' ([Convert]::ToHexString($bytes[0..7])) 'PNG signature'
function Read-BigEndian($Bytes, $Offset) {
    [uint32]$value = 0
    foreach ($i in $Offset..($Offset + 3)) { $value = ($value -shl 8) -bor $Bytes[$i] }
    $value
}
Assert-Equal 96 (Read-BigEndian $bytes 16) 'PNG width'
Assert-Equal 96 (Read-BigEndian $bytes 20) 'PNG height'

# Execute documented payloads against a session stub, with no credential or network boundary.
$send = Get-Content (Join-Path $skill 'references/send.md') -Raw
$payloads = @([regex]::Matches($send, '(?s)```json\s*(.*?)\s*```') | ForEach-Object { $_.Groups[1].Value | ConvertFrom-Json })
$sent = [Collections.Generic.List[object]]::new()
function reply {
    param($chat_id, $text, $format, $files)
    Assert-True ($format -cin @('text','markdownv2')) 'Explicit supported format'
    Assert-Equal $png $files[0] 'Existing bundled attachment path'
    Assert-True (Test-Path -LiteralPath $files[0]) 'Attachment is available'
    $sent.Add(@{Target=$chat_id;Text=$text;Format=$format})
    @{message_id='fixture-message';chat_id=$chat_id}
}
foreach ($payload in $payloads) {
    $payload.files = @($png)
    reply -chat_id $payload.chat_id -text $payload.text -format $payload.format -files $payload.files | Out-Null
}
Assert-Equal '123|456' ($sent.Target -join '|') 'ExplicitFormatAndPngDelivery separate targets'
Assert-Equal 'markdownv2|text' ($sent.Format -join '|') 'Notes-selected text stays explicit'
Assert-Equal 'Connection test\.' $sent[0].Text 'MarkdownV2 escapes punctuation'

# The generic CLI may default to text, but the owner-facing usage must require a format.
$codexUsage = [regex]::Match($send, '(?m)^legion telegram send .+$').Value
$requiredArguments = $codexUsage -replace '\[[^\]]*\]', ''
Assert-True ($requiredArguments -cmatch '(?:^|\s)--format\s') 'Codex owner sends specify format explicitly'
$formats = Get-Content (Join-Path $skill 'references/formats.md') -Raw
Assert-True ($send.Contains('[formats.md](formats.md)')) 'Sending points to formats.md'
Assert-True ($formats -match 'Default each independently' -and $formats -match 'format the notes name stays') 'Tone and format default independently'
