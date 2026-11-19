$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/bin/ps-ai-update.ps1') -NoRun
    $sandbox = Join-Path $repo ('.agents/temp/update-source-' + [guid]::NewGuid().ToString('N'))
    $plugin = Join-Path $sandbox 'unrelated/plugins/ps-ai'
    New-Item -ItemType Directory -Path $plugin, (Join-Path $sandbox 'unrelated/.git') -Force | Out-Null
    try {
        "[remote `"origin`"]`n url = https://github.com/example/dotfiles.git" | Set-Content (Join-Path $sandbox 'unrelated/.git/config')
        Assert-Equal 'BlackGad/ps-ai-marketplace' (Get-PsAiUpdateSource -PluginRoot $plugin) 'Unrelated ancestor checkout cannot supply update source'
        New-Item -ItemType Directory -Path (Join-Path $sandbox 'unrelated/.claude-plugin') | Out-Null
        '{"name":"ps-ai-marketplace","plugins":[{"name":"ps-ai","source":"./plugins/ps-ai"}]}' | Set-Content (Join-Path $sandbox 'unrelated/.claude-plugin/marketplace.json')
        Assert-Equal 'example/dotfiles' (Get-PsAiUpdateSource -PluginRoot $plugin) 'Verified marketplace checkout supplies its origin'
        $cached = Join-Path $sandbox 'unrelated/cache/ps-ai/1.0.0'
        New-Item -ItemType Directory -Path $cached -Force | Out-Null
        Assert-Equal 'BlackGad/ps-ai-marketplace' (Get-PsAiUpdateSource -PluginRoot $cached) 'Marketplace ancestor must own the running plugin location'
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe source fixture cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
