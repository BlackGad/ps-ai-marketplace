#!/bin/sh
# POSIX entry point: obtain PowerShell 7, then let install.ps1 own the install flow.
set -eu

fail() { printf '%s\n' "$*" >&2; exit 1; }

# Emit JSON string leaves as path<TAB>value. No jq, Python or PowerShell is
# needed to read the catalog and GitHub metadata. Control escapes are spaces;
# the URLs, asset names and SHA-256 digests we consume are ASCII strings.
json_strings() {
    awk '
    function whitespace() { while (substr(source, pos, 1) ~ /[ \t\r\n]/ && pos <= length(source)) pos++ }
    function string(    value, c, escape) {
        if (substr(source, pos++, 1) != "\"") exit 1
        while (pos <= length(source)) {
            c = substr(source, pos++, 1)
            if (c == "\"") return value
            if (c == "\\") {
                escape = substr(source, pos++, 1)
                if (escape == "u") { c = "?"; pos += 4 }
                else if (escape ~ /["\\\/]/) c = escape
                else if (escape ~ /[bfnrt]/) c = " "
                else exit 1
            }
            value = value c
        }
        exit 1
    }
    function parse(path,    c, key, item, child) {
        whitespace(); c = substr(source, pos, 1)
        if (c == "\"") { print path "\t" string(); return }
        if (c == "{" || c == "[") {
            pos++; whitespace(); item = 0
            if (substr(source, pos, 1) == (c == "{" ? "}" : "]")) { pos++; return }
            while (pos <= length(source)) {
                if (c == "{") {
                    key = string(); whitespace()
                    if (substr(source, pos++, 1) != ":") exit 1
                } else key = item++
                child = (path == "" ? key : path "." key)
                parse(child); whitespace()
                if (substr(source, pos, 1) == (c == "{" ? "}" : "]")) { pos++; return }
                if (substr(source, pos++, 1) != ",") exit 1
                whitespace()
            }
            exit 1
        }
        # Numbers, true, false and null contain no string leaves.
        if (c !~ /[-0-9tfn]/) exit 1
        while (pos <= length(source) && substr(source, pos, 1) !~ /[ \t\r\n,}\]]/) pos++
    }
    { source = source $0 "\n" }
    END { pos = 1; parse(""); whitespace(); if (pos <= length(source)) exit 1 }
    ' "$1"
}

json_field() { awk -F '\t' -v key="$2" '$1 == key { print $2; exit }' "$1"; }

is_pwsh7() {
    "$1" -NoProfile -Command 'if ($PSVersionTable.PSVersion.Major -eq 7) { exit 0 }; exit 1' >/dev/null 2>&1
}

main() {
    yes=0; dry_run=0; ref=stable
    # Rotate the original arguments once, appending their PowerShell equivalents.
    remaining=$#
    while [ "$remaining" -gt 0 ]; do
        option=$1; shift; remaining=$((remaining - 1))
        case "$option" in
            -y|--yes) yes=1; set -- "$@" -Yes ;;
            --dry-run) dry_run=1; set -- "$@" -DryRun ;;
            --main) ref=main; set -- "$@" -Ref main ;;
            --update) set -- "$@" -Update ;;
            --uninstall) set -- "$@" -Uninstall ;;
            --purge) set -- "$@" -Purge ;;
            --tools|--config-dir)
                [ "$remaining" -gt 0 ] || fail "Missing value for $option"
                value=$1; shift; remaining=$((remaining - 1))
                case "$value" in ''|--*) fail "Missing value for $option" ;; esac
                if [ "$option" = --tools ]; then set -- "$@" -Tools "$value"
                else set -- "$@" -ConfigDir "$value"; fi ;;
            *) fail "Unknown option: $option" ;;
        esac
    done

    pwsh=$(command -v pwsh || :)
    if [ -n "$pwsh" ] && is_pwsh7 "$pwsh"; then :
    elif [ -x "$HOME/.legion/tools/pwsh/pwsh" ] && is_pwsh7 "$HOME/.legion/tools/pwsh/pwsh"; then
        pwsh=$HOME/.legion/tools/pwsh/pwsh
    else pwsh=; fi
    if [ -n "$pwsh" ]; then
        printf '%s\n' 'skip: PowerShell 7 (already done)'
    else
        printf '%s\n' 'PowerShell 7 is missing.' \
            'Install the latest official PowerShell 7 archive, SHA-256 verified, to ~/.legion/tools/pwsh (no sudo).'
        [ "$dry_run" = 0 ] || return 0
        if [ "$yes" = 0 ]; then
            answer=
            # The one-line command consumes stdin; consent comes from the terminal.
            if ( : </dev/tty ) 2>/dev/null; then
                printf '%s' 'Install PowerShell 7 now? [y/N] ' >/dev/tty
                read -r answer </dev/tty || :
            fi
            case "$answer" in y|Y|yes|YES|Yes) ;; *) printf '%s\n' 'Nothing changed. Run again with --yes to apply.'; return 0 ;; esac
        fi
        case "$(uname -s)" in Darwin) platform=macos ;; Linux) platform=linux ;; *) fail 'Supported platforms: macOS and Linux.' ;; esac
        case "$(uname -m)" in x86_64|amd64) arch=x64 ;; arm64|aarch64) arch=arm64 ;; *) fail 'Supported CPUs: x64 and arm64.' ;; esac
    fi

    command -v curl >/dev/null 2>&1 || fail 'curl is required.'
    case "$HOME" in /*) ;; *) fail 'HOME must be an absolute path.' ;; esac
    mkdir -p "$HOME/.legion/temp"
    temporary=$(mktemp -d "$HOME/.legion/temp/install-shell.XXXXXX")
    # mktemp supplies the exact directory under HOME; never delete a caller path.
    trap 'rm -rf "$temporary"' 0
    trap 'exit 1' 1 2 3 15
    base=https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/$ref
    checkout=
    if [ -f "$0" ]; then
        folder=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
        if [ -f "$folder/install.ps1" ] && [ -f "$folder/plugins/legion/tools.json" ]; then checkout=$folder; fi
    fi

    if [ -z "$pwsh" ]; then
        if [ -n "$checkout" ]; then cp "$checkout/plugins/legion/tools.json" "$temporary/catalog.json"
        else curl -fsSL "$base/plugins/legion/tools.json" -o "$temporary/catalog.json"; fi
        json_strings "$temporary/catalog.json" >"$temporary/catalog.fields" || fail 'Invalid bootstrap catalog JSON.'
        metadata=$(json_field "$temporary/catalog.fields" bootstrap.posix.metadataUrl)
        template=$(json_field "$temporary/catalog.fields" "bootstrap.posix.assetNames.$platform")
        [ -n "$metadata" ] && [ -n "$template" ] || fail 'PowerShell archive recipe is missing from the catalog.'
        curl -fsSL "$metadata" -o "$temporary/release.json"
        json_strings "$temporary/release.json" >"$temporary/release.fields" || fail 'Invalid PowerShell release JSON.'
        version=$(json_field "$temporary/release.fields" tag_name)
        version=${version#v}
        case "$version" in ''|*[!0-9.]*) fail 'Invalid PowerShell release version.' ;; esac
        asset_name=$(printf '%s\n' "$template" | sed "s/{version}/$version/g; s/{arch}/$arch/g")
        asset=$(awk -F '\t' -v name="$asset_name" '$1 ~ /^assets\.[0-9]+\.name$/ && $2 == name { sub(/\.name$/, "", $1); print $1; exit }' "$temporary/release.fields")
        [ -n "$asset" ] || fail 'PowerShell archive is missing from the official release.'
        url=$(json_field "$temporary/release.fields" "$asset.browser_download_url")
        digest=$(json_field "$temporary/release.fields" "$asset.digest")
        hash=${digest#sha256:}
        case "$digest" in sha256:*) ;; *) fail 'PowerShell SHA-256 digest is missing from the official release.' ;; esac
        case "$hash" in *[!a-fA-F0-9]*) fail 'Invalid PowerShell SHA-256 digest.' ;; esac
        [ "${#hash}" = 64 ] || fail 'Invalid PowerShell SHA-256 digest.'
        case "$url" in https://github.com/PowerShell/PowerShell/releases/download/*) ;; *) fail 'Invalid official PowerShell archive URL.' ;; esac
        curl -fsSL "$url" -o "$temporary/pwsh.tar.gz"
        if command -v sha256sum >/dev/null 2>&1; then actual=$(sha256sum "$temporary/pwsh.tar.gz")
        elif command -v shasum >/dev/null 2>&1; then actual=$(shasum -a 256 "$temporary/pwsh.tar.gz")
        else fail 'sha256sum or shasum is required.'; fi
        actual=${actual%% *}
        expected=$(printf '%s' "$hash" | tr 'A-F' 'a-f')
        [ "$actual" = "$expected" ] || fail 'PowerShell SHA-256 digest mismatch; download deleted.'
        destination=$HOME/.legion/tools/pwsh
        mkdir -p "$destination"
        tar -xzf "$temporary/pwsh.tar.gz" -C "$destination"
        chmod +x "$destination/pwsh"
        pwsh=$destination/pwsh
        is_pwsh7 "$pwsh" || fail 'The portable PowerShell 7 could not run. Check the platform runtime dependencies.'
    fi
    # Also let the root stub find a portable copy in its child process.
    PATH=$(dirname "$pwsh"):$PATH
    export PATH
    if [ -n "$checkout" ]; then installer=$checkout/install.ps1
    else
        installer=$temporary/install.ps1
        curl -fsSL "$base/install.ps1" -o "$installer"
    fi
    # -File binds one string per shell argument. Split --tools here so the root
    # stub receives a typed array, keeping spaces and shell metacharacters literal.
    cat >"$temporary/launch.ps1" <<'POWERSHELL'
param([string]$Installer, [string]$Tools, [string]$ConfigDir,
    [string]$Ref, [switch]$Update, [switch]$Uninstall, [switch]$Purge,
    [switch]$DryRun, [switch]$Yes)
$ErrorActionPreference = 'Stop'
$parameters = @{}
foreach ($name in $PSBoundParameters.Keys) {
    if ($name -eq 'Installer') { continue }
    $parameters[$name] = if ($name -eq 'Tools') { [string[]]$Tools.Split(',') } else { $PSBoundParameters[$name] }
}
& $Installer @parameters
exit $LASTEXITCODE
POWERSHELL
    if ( : </dev/tty ) 2>/dev/null; then
        "$pwsh" -NoProfile -File "$temporary/launch.ps1" -Installer "$installer" "$@" </dev/tty
    else "$pwsh" -NoProfile -File "$temporary/launch.ps1" -Installer "$installer" "$@"; fi
}

main "$@"
