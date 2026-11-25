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

    legion=$home/.legion
    app=$legion/app/$version
    marker=$app/.legion-app-ready
    for path in "$legion" "$legion/app" "$app" "$marker" "$legion/python"; do
        [ ! -L "$path" ] || return 1
    done
    [ -f "$marker" ] && [ -r "$marker" ] || return 1
    if [ -s "$marker" ]; then
        {
            IFS= read -r name || [ -n "$name" ] || return 1
            if IFS= read -r extra || [ -n "$extra" ]; then
                return 1
            fi
        } < "$marker" || return 1
        name=${name%"$(printf '\r')"}
    else
        # 0.17.0 published empty markers. Recreate its hash of the resolved installed app path.
        key=$(CDPATH= cd -P -- "$app" && pwd -P) || return 1
        if [ "${OS:-}" = Windows_NT ]; then
            key=$(cygpath -w "$key") || return 1
            key=$(printf '%s' "$key" | LC_ALL=C.UTF-8 awk '{ printf "%s", tolower($0) }') || return 1
        fi
        if command -v sha256sum >/dev/null 2>&1; then
            digest=$(printf '%s' "$key" | sha256sum) || return 1
        else
            digest=$(printf '%s' "$key" | shasum -a 256) || return 1
        fi
        name=env-$(printf '%.12s' "$digest")
    fi
    case "$name" in
        env-????????????)
            case "${name#env-}" in *[!0123456789abcdef]*) return 1 ;; esac
            ;;
        *) return 1 ;;
    esac

    environment=$legion/python/$name
    python=$environment/$executable
    [ ! -L "$environment" ] && [ ! -L "${python%/*}" ] || return 1
    if [ "${OS:-}" = Windows_NT ]; then
        [ ! -L "$python" ] || return 1
    fi
    [ -f "$python" ] && [ -x "$python" ] || return 1
    "$python" -I -B -S "$entry" --home "$home" --format "$format"
}
