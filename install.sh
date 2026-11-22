#!/bin/sh
# POSIX entry point: obtain PowerShell 7, then let install.ps1 own the install flow.
set -eu

fail() { printf '%s\n' "$*" >&2; exit 1; }

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
        case "$(uname -s)" in Darwin) platform=osx ;; Linux) platform=linux ;; *) fail 'Supported platforms: macOS and Linux.' ;; esac
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
        release=https://github.com/PowerShell/PowerShell/releases
        redirect=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$release/latest")
        case "$redirect" in "$release/tag/v"*) version=${redirect#"$release/tag/v"} ;; *) fail 'Invalid PowerShell release redirect.' ;; esac
        case "$version" in ''|*[!0-9.]*) fail 'Invalid PowerShell release version.' ;; esac
        asset_name=powershell-$version-$platform-$arch.tar.gz
        url=$release/download/v$version/$asset_name
        curl -fsSL "$release/download/v$version/hashes.sha256" -o "$temporary/hashes.sha256"
        # The release hash list is UTF-16LE with BOM and CRLF. Its names and
        # digests are ASCII; remove NUL bytes, the BOM bytes and CR without iconv.
        hash=$(LC_ALL=C tr -d '\000\377\376\357\273\277\r' <"$temporary/hashes.sha256" |
            awk -v name="$asset_name" '$2 == name || $2 == "*" name { print $1; exit }')
        case "$hash" in ''|*[!a-fA-F0-9]*) fail 'Invalid PowerShell SHA-256 digest.' ;; esac
        [ "${#hash}" = 64 ] || fail 'Invalid PowerShell SHA-256 digest.'
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
    if ( : </dev/tty ) 2>/dev/null; then
        "$pwsh" -NoProfile -File "$installer" "$@" </dev/tty
    else "$pwsh" -NoProfile -File "$installer" "$@"; fi
}

main "$@"
