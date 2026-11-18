#!/bin/sh
if ! command -v pwsh >/dev/null 2>&1; then
  case "$(uname -s)" in
    Darwin) echo 'PowerShell 7 is missing. On macOS: brew install --cask powershell' ;;
    *) echo 'PowerShell 7 is missing. On Linux: https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux' ;;
  esac
  exit 1
fi
exec pwsh -NoProfile -File "$(dirname "$0")/install.ps1" "$@"
