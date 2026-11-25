#!/bin/sh
# Locate the ready runtime before Python starts. Errors are rendered by the host manifest.
legion_session_start() {
    entry=$1
    format=$2
    root=${entry%/hooks/session_start.py}

    case "${OS:-}" in
        Windows_NT)
            home=${LEGION_HOME:-${USERPROFILE:-${HOME:-}}}
            [ -n "$home" ] || return 1
            # Keep native Windows paths literal and convert MSYS paths before passing them to Python.
            case "$home" in
                [A-Za-z]:*|\\\\*) ;;
                *) home=$(cygpath -m "$home") || return 1 ;;
            esac
            executable=Scripts/python.exe
            ;;
        *)
            home=${LEGION_HOME:-${HOME:-}}
            executable=bin/python3
            ;;
    esac
    [ -n "$home" ] || return 1

    # Hand-built, reason: the manifest version is on its own line and no JSON parser is required before Python.
    version=$(sed -nE 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"([0-9]+(\.[0-9]+){0,2}(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?)".*$/\1/p' "$root/plugin.json") || return 1
    newline='
'
    case "$version" in ''|*"$newline"*) return 1 ;; esac

    {
        IFS= read -r name || [ -n "$name" ] || return 1
        if IFS= read -r extra || [ -n "$extra" ]; then
            return 1
        fi
    } < "$home/.legion/app/$version/.legion-app-ready" || return 1
    case "$name" in
        env-????????????)
            case "${name#env-}" in *[!0123456789abcdef]*) return 1 ;; esac
            ;;
        *) return 1 ;;
    esac

    python=$home/.legion/python/$name/$executable
    [ -f "$python" ] && [ -x "$python" ] || return 1
    "$python" -I -B -S "$entry" --home "$home" --format "$format"
}
