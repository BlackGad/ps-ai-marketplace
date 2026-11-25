#!/bin/sh
# POSIX entry point: obtain uv, then hand every option to the Python `legion install` command.
# Hand-built, reason: this runs before uv and Python exist, so it cannot use any Python library; it stays small on purpose.
set -eu

fail() { printf '%s\n' "$*" >&2; exit 1; }

# Every download, and every redirect it follows, must be HTTPS.
fetch() { curl --proto '=https' --proto-redir '=https' -fsSL "$@"; }

# Asks the owner in the terminal; --yes answers for them.
confirm() {
    [ "$yes" = 1 ] && return 0
    answer=
    # The one-line command consumes stdin; consent comes from the terminal.
    if ( : </dev/tty ) 2>/dev/null; then
        printf '%s' "$1 [y/N] " >/dev/tty
        read -r answer </dev/tty || :
    fi
    case "$answer" in y|Y|yes|YES|Yes) return 0 ;; esac
    printf '%s\n' 'Nothing changed. Run again with --yes to apply.'
    return 1
}

# uv is found on PATH, in the legion bin folder (which `legion install` puts on the shell PATH), or in the folder its own installer uses.
find_uv() {
    uv=$(command -v uv || :)
    if [ -z "$uv" ]; then
        for folder in "$HOME/.legion/bin" "${UV_INSTALL_DIR:-}" "${XDG_BIN_HOME:-}" "$HOME/.local/bin"; do
            if [ -n "$folder" ] && [ -x "$folder/uv" ]; then uv=$folder/uv; break; fi
        done
    fi
    [ -n "$uv" ]
}

# Downloads the latest uv release for this system, checks its SHA-256 digest and publishes it to ~/.legion/bin.
install_uv() {
    case "$(uname -s)-$(uname -m)" in
        Darwin-arm64) triple=aarch64-apple-darwin ;;
        Darwin-x86_64) triple=x86_64-apple-darwin ;;
        Linux-aarch64|Linux-arm64) triple=aarch64-unknown-linux-gnu ;;
        Linux-x86_64) triple=x86_64-unknown-linux-gnu ;;
        *) fail "No uv release is known for $(uname -s) $(uname -m)." ;;
    esac
    asset="uv-$triple.tar.gz"
    url="https://github.com/astral-sh/uv/releases/latest/download/$asset"
    fetch "$url.sha256" -o "$temporary/uv.tar.gz.sha256"
    read -r expected filename < "$temporary/uv.tar.gz.sha256" || :
    case "$expected" in *[!0-9a-fA-F]*|'') fail 'The uv asset or its SHA-256 digest is missing from the official release.' ;; esac
    [ "${#expected}" -eq 64 ] && [ "$filename" = "$asset" ] || fail 'The uv asset or its SHA-256 digest is missing from the official release.'
    fetch "$url" -o "$temporary/uv.tar.gz"
    if command -v sha256sum >/dev/null 2>&1; then actual=$(sha256sum "$temporary/uv.tar.gz")
    elif command -v shasum >/dev/null 2>&1; then actual=$(shasum -a 256 "$temporary/uv.tar.gz")
    else fail 'sha256sum or shasum is required.'; fi
    actual=${actual%% *}
    expected=$(printf '%s' "$expected" | tr 'A-F' 'a-f')
    if [ "$actual" != "$expected" ]; then
        rm -f "$temporary/uv.tar.gz"
        fail 'uv SHA-256 digest mismatch; download deleted.'
    fi
    mkdir "$temporary/uv"
    tar -xzf "$temporary/uv.tar.gz" -C "$temporary/uv" --strip-components=1
    "$temporary/uv/uv" --version >/dev/null 2>&1 || fail 'The downloaded uv does not run; nothing was installed.'
    mkdir -p "$HOME/.legion/bin"
    # Copy beside the target, then rename: an interrupted run never leaves a partial uv.
    cp "$temporary/uv/uv" "$HOME/.legion/bin/uv.new"
    mv -f "$HOME/.legion/bin/uv.new" "$HOME/.legion/bin/uv"
}

main() {
    yes=0; dry_run=0; ref=stable
    # Rotate the original arguments once, appending their `legion install` spelling.
    remaining=$#
    while [ "$remaining" -gt 0 ]; do
        option=$1; shift; remaining=$((remaining - 1))
        case "$option" in
            -y|--yes) yes=1; set -- "$@" --yes ;;
            --dry-run) dry_run=1; set -- "$@" --dry-run ;;
            --main) ref=main; set -- "$@" --ref main ;;
            --update) set -- "$@" --update ;;
            --uninstall) set -- "$@" --uninstall ;;
            --purge) set -- "$@" --purge ;;
            --tools|--config-dir)
                [ "$remaining" -gt 0 ] || fail "Missing value for $option"
                value=$1; shift; remaining=$((remaining - 1))
                case "$value" in ''|--*) fail "Missing value for $option" ;; esac
                if [ "$option" = --tools ]; then set -- "$@" --tool "$value"
                else set -- "$@" --config-dir "$value"; fi ;;
            *) fail "Unknown option: $option" ;;
        esac
    done

    command -v curl >/dev/null 2>&1 || fail 'curl is required.'
    case "$HOME" in /*) ;; *) fail 'HOME must be an absolute path.' ;; esac

    if find_uv; then
        printf '%s\n' 'skip: uv (already done)'
    else
        printf '%s\n' 'uv is missing.' \
            'Install uv: download the latest official uv release, verified with its SHA-256 digest, to ~/.legion/bin/, which the legion install then puts on your PATH.'
        [ "$dry_run" = 0 ] || return 0
        confirm 'Install uv now?' || return 0
    fi

    # In the system temp folder, outside .legion, so a purge can delete .legion while this is in use.
    temporary=$(mktemp -d "${TMPDIR:-/tmp}/legion-install.XXXXXX")
    # mktemp supplies the exact directory; never delete a caller path.
    trap 'rm -rf "$temporary"' 0
    trap 'exit 1' 1 2 3 15

    if ! find_uv; then
        install_uv
        find_uv || fail 'uv was installed but could not be found; open a new terminal and run the bootstrap again.'
    fi
    PATH=$(dirname "$uv"):$PATH
    export PATH

    # Previews never let uv download Python; an ordinary run asks first.
    if ! "$uv" python find '>=3.12' >/dev/null 2>&1; then
        printf '%s\n' 'Python 3.12 is missing. uv can download it for legion.'
        [ "$dry_run" = 0 ] || return 0
        confirm 'Download Python with uv now?' || return 0
    fi

    # The plugin folder that holds the Python project: this checkout, or the archive from the fixed legion repository.
    project=
    if [ -f "$0" ]; then
        folder=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
        if [ -f "$folder/plugins/legion/pyproject.toml" ]; then project=$folder/plugins/legion; fi
    fi
    if [ -z "$project" ]; then
        mkdir "$temporary/source"
        if ! fetch "https://github.com/BlackGad/ps-legion-marketplace/archive/refs/heads/$ref.tar.gz" -o "$temporary/legion.tar.gz"; then
            [ "$ref" != stable ] || fail 'could not find the latest release; try again or run with --main'
            fail "could not download the $ref code"
        fi
        tar -xzf "$temporary/legion.tar.gz" -C "$temporary/source" --strip-components=1
        project=$temporary/source/plugins/legion
        [ -f "$project/pyproject.toml" ] || fail 'Plugin archive is missing the legion project.'
    fi

    # The project environment lives beside the downloaded copy and goes with it.
    UV_PROJECT_ENVIRONMENT=$temporary/env
    export UV_PROJECT_ENVIRONMENT
    # The one-line command consumes stdin; the installer's questions come from the terminal.
    status=0
    if ( : </dev/tty ) 2>/dev/null; then
        "$uv" run --project "$project" --frozen --quiet legion --home "$HOME" install "$@" </dev/tty || status=$?
    else "$uv" run --project "$project" --frozen --quiet legion --home "$HOME" install "$@" || status=$?; fi
    return "$status"
}

main "$@"
