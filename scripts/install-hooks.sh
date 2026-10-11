#!/usr/bin/env bash
# install-hooks.sh — installs the undercover commit-msg hook from this toolkit
# into a target git repo's hooks directory, or into the global git hooks directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_SOURCE_DIR="$(cd "${SCRIPT_DIR}/../hooks" && pwd 2>/dev/null || true)"
HOOK_NAME="commit-msg"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Installs the undercover commit-msg hook from this toolkit.

OPTIONS:
  --global      Install to ~/.config/git/hooks/ (global git hooks directory)
  --uninstall   Remove the installed hook
  --help        Show this help message

Default (no flags): install to .git/hooks/ of the current directory.
EOF
}

die() {
    echo "Error: $*" >&2
    exit 1
}

# Validate hook source directory and file exist
check_source() {
    if [[ -z "${HOOKS_SOURCE_DIR}" || ! -d "${HOOKS_SOURCE_DIR}" ]]; then
        die "Hooks source directory not found (expected: ${SCRIPT_DIR}/../hooks)"
    fi
    if [[ ! -f "${HOOKS_SOURCE_DIR}/${HOOK_NAME}" ]]; then
        die "Hook source not found: ${HOOKS_SOURCE_DIR}/${HOOK_NAME}"
    fi
}

# Resolve the target hooks directory
resolve_target_dir() {
    local mode="$1"  # "global" or "local"

    if [[ "${mode}" == "global" ]]; then
        local global_hooks
        global_hooks="$(git config --global core.hooksPath 2>/dev/null || true)"
        if [[ -n "${global_hooks}" ]]; then
            echo "${global_hooks}"
        else
            echo "${HOME}/.config/git/hooks"
        fi
    else
        # Local mode: must be inside a git repo
        command -v git >/dev/null 2>&1 || die "git is not available on PATH"
        local git_dir
        git_dir="$(git rev-parse --git-dir 2>/dev/null)" \
            || die "Current directory is not inside a git repository"
        echo "${git_dir}/hooks"
    fi
}

# Install the hook
do_install() {
    local target_dir="$1"

    mkdir -p "${target_dir}"

    local dest="${target_dir}/${HOOK_NAME}"

    if [[ -e "${dest}" ]]; then
        echo "Warning: ${dest} already exists — overwriting."
    fi

    cp "${HOOKS_SOURCE_DIR}/${HOOK_NAME}" "${dest}"
    chmod +x "${dest}"
    echo "Installed ${HOOK_NAME} hook to ${dest}"
}

# Uninstall the hook
do_uninstall() {
    local target_dir="$1"

    local dest="${target_dir}/${HOOK_NAME}"

    if [[ ! -e "${dest}" ]]; then
        echo "No ${HOOK_NAME} hook found at ${dest} — nothing to remove."
        exit 0
    fi

    rm -f "${dest}"
    echo "Removed ${HOOK_NAME} hook from ${dest}"
}

main() {
    local mode="local"
    local action="install"

    for arg in "$@"; do
        case "${arg}" in
            --global)    mode="global" ;;
            --uninstall) action="uninstall" ;;
            --help|-h)   usage; exit 0 ;;
            *)           die "Unknown option: ${arg}. Run with --help for usage." ;;
        esac
    done

    command -v git >/dev/null 2>&1 || die "git is not available on PATH"

    local target_dir
    target_dir="$(resolve_target_dir "${mode}")"

    if [[ "${action}" == "uninstall" ]]; then
        do_uninstall "${target_dir}"
    else
        check_source
        do_install "${target_dir}"
    fi
}

main "$@"
