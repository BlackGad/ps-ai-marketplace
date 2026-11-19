$root = Split-Path $PSScriptRoot -Parent
$skill = Join-Path $root 'plugins/ps-ai/skills/ps-ai-telegram'
$png = Join-Path $skill 'assets/test.png'
Assert-True (Test-Path $png) 'Bundled test image exists'
$bytes = [IO.File]::ReadAllBytes($png)
Assert-Equal '89504E470D0A1A0A' ([Convert]::ToHexString($bytes[0..7])) 'PNG signature'
function Read-BigEndian($Bytes, $Offset) {
    [uint32]$value = 0
    foreach ($i in $Offset..($Offset + 3)) { $value = ($value -shl 8) -bor $Bytes[$i] }
    $value
}
$offset = 8
$types = @()
$compressed = [IO.MemoryStream]::new()
while ($offset -lt $bytes.Length) {
    $length = Read-BigEndian $bytes $offset
    $type = [Text.Encoding]::ASCII.GetString($bytes, $offset + 4, 4)
    $types += $type
    [uint32]$crc = [uint32]::MaxValue
    foreach ($index in ($offset + 4)..($offset + 7 + $length)) {
        $crc = $crc -bxor $bytes[$index]
        foreach ($bit in 1..8) { $crc = if ($crc -band 1) { ($crc -shr 1) -bxor [uint32]3988292384 } else { $crc -shr 1 } }
    }
    $crc = $crc -bxor [uint32]::MaxValue
    Assert-Equal (Read-BigEndian $bytes ($offset + 8 + $length)) $crc "PNG $type checksum"
    if ($type -eq 'IHDR') {
        Assert-Equal 96 (Read-BigEndian $bytes ($offset + 8)) 'PNG width'
        Assert-Equal 96 (Read-BigEndian $bytes ($offset + 12)) 'PNG height'
    }
    if ($type -eq 'IDAT') { $compressed.Write($bytes, $offset + 8, $length) }
    $offset += 12 + $length
}
Assert-Equal 'IHDR|IDAT|IEND' ($types -join '|') 'PNG chunk structure'
$compressed.Position = 0
$decoder = [IO.Compression.ZLibStream]::new($compressed, [IO.Compression.CompressionMode]::Decompress)
$pixels = [IO.MemoryStream]::new()
$decoder.CopyTo($pixels)
Assert-Equal (96 * (96 * 3 + 1)) $pixels.Length 'PNG decompresses fully'
$decoder.Dispose(); $pixels.Dispose(); $compressed.Dispose()

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

# Execute the documented session install command with fake installed state.
$installText = Get-Content (Join-Path $skill 'references/install.md') -Raw
$installCommand = [regex]::Match($installText, '(?s)```text\s*(.*?)\s*```').Groups[1].Value
$pluginState = @{Installed=$false;Executions=0}
function Invoke-FixtureSessionInstall {
    param([string]$Command, [switch]$Yes)
    Assert-Equal '/plugin install telegram@claude-plugins-official' $Command 'Documented plugin command'
    if ($pluginState.Installed) { 'skip: channel plugin (already done)'; return }
    if (-not $Yes) { return }
    $pluginState.Executions++
    $pluginState.Installed=$true
}
Invoke-FixtureSessionInstall $installCommand
Assert-Equal 0 $pluginState.Executions 'Plugin preview and decline execute nothing'
Invoke-FixtureSessionInstall $installCommand -Yes
Invoke-FixtureSessionInstall $installCommand -Yes | Out-Null
Assert-Equal 1 $pluginState.Executions 'Approved and repeated install executes once'
