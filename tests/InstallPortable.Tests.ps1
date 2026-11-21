$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/bin/legion-install-tool.ps1') -NoRun
    $sandbox = Join-Path $repo ('.agents/temp/portable-' + [guid]::NewGuid().ToString('N'))
    function Get-ToolInstallRoot { param($Tool) $sandbox }
    try {
        foreach ($version in @('22.9.0','22.10.0','20.99.0')) {
            $folder = Join-Path $sandbox "node-v$version-win-x64"
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            '' | Set-Content (Join-Path $folder 'node.exe')
        }
        Assert-Equal (Join-Path $sandbox 'node-v22.10.0-win-x64/node.exe') (Get-ToolPortableCommand -Tool node) 'Portable Node selects numerically newest installed version'
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe portable fixture cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
