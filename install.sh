#!/bin/sh
# POSIX entry point: obtain uv, then hand every option to the Python `legion install` command.
# Hand-built, reason: this runs before uv and Python exist, so it cannot use any Python library; it stays small on purpose.
set -eu

fail() { printf '%s\n' "$*" >&2; exit 1; }

# uv is found on PATH, or in the folder its own installer uses.
find_uv() {
    uv=$(command -v uv || :)
    if [ -z "$uv" ]; then
        for folder in "${UV_INSTALL_DIR:-}" "${XDG_BIN_HOME:-}" "$HOME/.local/bin"; do
            if [ -n "$folder" ] && [ -x "$folder/uv" ]; then uv=$folder/uv; break; fi
        done
    fi
    [ -n "$uv" ]
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
            'Install uv: download the official uv installer (https://astral.sh/uv/install.sh), which checks its download and adds uv to your shell profile.'
        [ "$dry_run" = 0 ] || return 0
        if [ "$yes" = 0 ]; then
            answer=
            # The one-line command consumes stdin; consent comes from the terminal.
            if ( : </dev/tty ) 2>/dev/null; then
                printf '%s' 'Install uv now? [y/N] ' >/dev/tty
                read -r answer </dev/tty || :
            fi
            case "$answer" in y|Y|yes|YES|Yes) ;; *) printf '%s\n' 'Nothing changed. Run again with --yes to apply.'; return 0 ;; esac
        fi
    fi

    mkdir -p "$HOME/.legion/temp"
    temporary=$(mktemp -d "$HOME/.legion/temp/install-shell.XXXXXX")
    # mktemp supplies the exact directory under HOME; never delete a caller path.
    trap 'rm -rf "$temporary"' 0
    trap 'exit 1' 1 2 3 15

    if ! find_uv; then
        curl -fsSL https://astral.sh/uv/install.sh -o "$temporary/uv-install.sh"
        sh "$temporary/uv-install.sh"
        find_uv || fail 'uv was installed but could not be found; open a new terminal and run the bootstrap again.'
    fi
    PATH=$(dirname "$uv"):$PATH
    export PATH

    # The plugin folder that holds the Python project: this checkout, or the archive from the fixed legion repository.
    project=
    if [ -f "$0" ]; then
        folder=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
        if [ -f "$folder/plugins/legion/pyproject.toml" ]; then project=$folder/plugins/legion; fi
    fi
    if [ -z "$project" ]; then
        mkdir "$temporary/source"
        if ! curl -fsSL "https://github.com/BlackGad/ps-legion-marketplace/archive/refs/heads/$ref.tar.gz" -o "$temporary/legion.tar.gz"; then
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
        "$uv" run --project "$project" --frozen --quiet legion install "$@" </dev/tty || status=$?
    else "$uv" run --project "$project" --frozen --quiet legion install "$@" || status=$?; fi
    return "$status"
}

main "$@"
