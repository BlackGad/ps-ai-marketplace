$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$library = Join-Path $root 'plugins/legion/bin/lib/commands.ps1'
Assert-True (Test-Path -LiteralPath $library) 'Owner-command library exists'
. $library
$commands = Get-LegionOwnerCommands
Assert-Equal 'legion' ($commands.Keys -join '|') 'Legion is the only owner command'
Assert-Equal 'legion.ps1' ($commands.Values -join '|') 'Command targets'

$scratch = Join-Path $root ('.agents/temp/commands-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
$target = Join-Path $scratch "owner's plugin/bin/legion.ps1"
$unix = Get-LegionShimText -Script $target
. (Join-Path $root 'plugins/legion/bin/legion-account.ps1') -NoRun
$expected = "#!/bin/sh`n" + 'exec pwsh -NoProfile -File ' + (ConvertTo-LegionShellLiteral $target) + ' "$@"' + "`n"
Assert-Equal $expected $unix 'Unix shim quotes spaces and apostrophes with the shared shell literal'
$windows = Get-LegionShimText -Script 'C:\plugin folder\bin\legion.ps1' -Windows
Assert-Equal "@pwsh -NoProfile -File `"C:\plugin folder\bin\legion.ps1`" %* & (goto) 2>nul & exit /b`r`n" $windows 'Windows shim quotes the target'
foreach ($text in @($windows.Replace(' %*', ' -Repo "C:\work folder" %*'), $unix.Replace(' "$@"', ' -Repo "work folder" "$@"'))) {
    $isBatch = $text.StartsWith('@')
    $match = Get-LegionOwnerCommandTarget -Text $text -Script legion.ps1 -Batch:$isBatch
    Assert-True ([bool]$match) 'R4 B2 literal quoted owner arguments are recognized'
    $updated = Update-LegionOwnerCommandText -Text $text -Script legion.ps1 -Runner '/new/bin/legion.ps1' -Windows:$isBatch
    Assert-True ($updated.Contains('work folder"')) 'R4 B2 retarget preserves the quoted owner argument'
}

$path = Join-Path $scratch 'legion'
Assert-Equal $false (Test-LegionOwnerCommandFile -Path $path -Script legion.ps1) 'Missing command is not owned'
foreach ($text in @($unix, $windows, $unix.Replace(' "$@"', ' --extra "$@"'), $windows.Replace(' %*', ' --extra %*'),
    'pwsh -NoProfile -File /plugin/bin/legion.ps1', '@pwsh -NoProfile -File C:\plugin\bin\legion.ps1')) {
    $samplePath = if ($text.StartsWith('@')) { "$path.cmd" } else { $path }
    [IO.File]::WriteAllText($samplePath, $text)
    Assert-True (Test-LegionOwnerCommandFile -Path $samplePath -Script legion.ps1) 'Generated and owner-extended shims are recognized'
    Assert-Equal $false (Test-LegionOwnerCommandFile -Path $samplePath -Script legion-status.ps1) 'Another owner command target does not match'
}
foreach ($text in @('unrelated command', 'pwsh -NoProfile -File "/plugin/legion.ps1"', 'echo "/plugin/bin/legion.ps1"', 'python -File "/plugin/bin/legion.ps1"')) {
    [IO.File]::WriteAllText($path, $text)
    Assert-Equal $false (Test-LegionOwnerCommandFile -Path $path -Script legion.ps1) 'Unrelated files are not owned'
}
Assert-Equal $false (Test-LegionOwnerCommandFile -Path $scratch -Script legion.ps1) 'A directory is not an owner command'

# C-1: only a launcher line whose -File argument is the target counts; comments and later arguments do not.
$lookalikes = @(
    "#!/bin/sh`n# exec pwsh -NoProfile -File '/plugin/bin/legion.ps1' `"`$@`"`necho owner command",
    "@rem pwsh -NoProfile -File `"C:\plugin\bin\legion.ps1`" %*`r`n@echo owner command",
    "pwsh -NoProfile -File /owner/custom.ps1 /plugin/bin/legion.ps1",
    "echo ok # pwsh -NoProfile -File /plugin/bin/legion.ps1",
    "python run.py pwsh -File /plugin/bin/legion.ps1")
foreach ($text in $lookalikes) {
    [IO.File]::WriteAllText($path, $text)
    Assert-Equal $false (Test-LegionOwnerCommandFile -Path $path -Script legion.ps1) 'A comment or a later argument naming the script is not a legion command'
}

# C-3: one matcher finds the target as written, so refresh can replace it without index arithmetic.
$match = Get-LegionOwnerCommandTarget -Text $unix -Script legion.ps1
Assert-Equal $target $match.Path 'Matcher unquotes the shell literal'
Assert-Equal (ConvertTo-LegionShellLiteral $target) $unix.Substring($match.Start, $match.Length) 'Matcher reports the target span as written'
Assert-Equal $null (Get-LegionOwnerCommandTarget -Text 'unrelated' -Script legion.ps1) 'No target in an unrelated file'

# C-2: an owned command whose script is gone is stale.
Assert-Equal 'missing' (Get-LegionOwnerCommandState -Path (Join-Path $scratch 'nothing') -Script legion.ps1) 'Absent file is missing'
[IO.File]::WriteAllText($path, 'unrelated command')
Assert-Equal 'blocked' (Get-LegionOwnerCommandState -Path $path -Script legion.ps1) 'Foreign file is blocked'
[IO.File]::WriteAllText($path, $unix)
Assert-Equal 'stale' (Get-LegionOwnerCommandState -Path $path -Script legion.ps1) 'Owned command with a missing script is stale'
New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
'' | Set-Content -LiteralPath $target
Assert-Equal 'owned' (Get-LegionOwnerCommandState -Path $path -Script legion.ps1) 'Owned command with an existing script is owned'
$moved = Update-LegionOwnerCommandText -Text ($unix.Replace(' "$@"', ' --extra "$@"')) -Script legion.ps1 -Runner '/new/bin/legion.ps1'
Assert-Equal ($unix.Replace((ConvertTo-LegionShellLiteral $target), "'/new/bin/legion.ps1'").Replace(' "$@"', ' --extra "$@"')) $moved 'Retarget keeps the owner flags'

# K3: the whole file must be the generated launcher; a custom launcher that runs its own code first is not ours.
$customLaunchers = @(
    "#!/bin/sh`necho before`nexec pwsh -NoProfile -File '/plugin/bin/legion.ps1' `"`$@`"`n",
    "#!/bin/sh`nexec pwsh -NoProfile -File '/plugin/bin/legion.ps1' `"`$@`"`necho after`n",
    "#!/bin/sh`nexport OWNER_SETTING=1`nexec pwsh -NoProfile -File '/plugin/bin/legion.ps1' `"`$@`"`n",
    "@echo off`r`nset OWNER_SETTING=1`r`n@pwsh -NoProfile -File `"C:\pluginin\legion.ps1`" %*`r`n",
    "#!/bin/sh`nexec pwsh -NoProfile -File '/plugin/bin/legion.ps1' `"`$@`"; rm -rf /tmp/mine`n",
    "#!/bin/sh`nexec pwsh -NoProfile -File '/plugin/bin/legion.ps1' `"`$@`" && echo done`n")
foreach ($text in $customLaunchers) {
    [IO.File]::WriteAllText($path, $text)
    Assert-Equal $false (Test-LegionOwnerCommandFile -Path $path -Script legion.ps1) "A launcher with other code is kept: $text"
    Assert-Equal 'blocked' (Get-LegionOwnerCommandState -Path $path -Script legion.ps1) 'A launcher with other code is blocked'
}
foreach ($text in @($unix.TrimEnd("`n"), ($unix + "`n`n"), $unix.Replace(' "$@"', ' -- --extra=1 "$@"'))) {
    [IO.File]::WriteAllText($path, $text)
    Assert-True (Test-LegionOwnerCommandFile -Path $path -Script legion.ps1) 'The generated launcher with blank lines or trailing flags is still ours'
}

# G2: a batch shim writes % as %%, so a target under a folder with % must still be found.
$percentFolder = Join-Path $scratch 'plugin 100%'
$percentScript = Join-Path $percentFolder 'bin/legion.ps1'
New-Item -ItemType Directory -Path (Split-Path $percentScript) -Force | Out-Null
'' | Set-Content -LiteralPath $percentScript
$batchPath = Join-Path $scratch 'legion.cmd'
$dollarArgument = ' -Repo "\\server\team$\work folder"'
$dollarText = $windows.Replace(' %*', $dollarArgument + ' %*')
[IO.File]::WriteAllText($batchPath, $dollarText)
Assert-True (Test-LegionOwnerCommandFile -Path $batchPath -Script legion.ps1) 'R5 B2 batch launcher accepts a quoted dollar path'
$updated = Update-LegionOwnerCommandText -Text $dollarText -Script legion.ps1 -Runner 'C:\new\bin\legion.ps1' -Windows
Assert-True ($updated.Contains('"C:\new\bin\legion.ps1"') -and $updated.Contains($dollarArgument)) 'R5 B2 batch retarget preserves the literal dollar path'
Assert-Equal $null (Get-LegionOwnerCommandTarget -Text $dollarText -Script legion.ps1) 'R5 B2 shell matcher still rejects dollar expansion in double quotes'
[IO.File]::WriteAllText($batchPath, (Get-LegionShimText -Script $percentScript -Windows))
Assert-Equal 'owned' (Get-LegionOwnerCommandState -Path $batchPath -Script legion.ps1) 'A batch shim target with a percent sign resolves to its real file'
Assert-Equal $percentScript (Get-LegionOwnerCommandTarget -Text (Get-LegionShimText -Script $percentScript -Windows) -Script legion.ps1 -Batch).Path 'Batch quoting is decoded'
