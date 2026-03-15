#!/bin/bash
# Shared Agent Ankh management CLI used by the package bin and deployed wrapper.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="${AGENT_ANKH_PKG_ROOT:-${PKG_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}}"

ANKH_HOME="${AGENT_ANKH_HOME:-$HOME/.agent/extensions/ankh}"
ANKH_RUNTIME_DIR="${AGENT_ANKH_RUNTIME_DIR:-$ANKH_HOME/runtime}"
AGENT_BIN="${AGENT_BIN:-$HOME/.agent/extensions/ankh/bin}"

DEFAULT_HERMES_HOME="${DEFAULT_HERMES_HOME:-$HOME/.hermes}"
DEFAULT_HERMES_INSTALL_DIR="${DEFAULT_HERMES_INSTALL_DIR:-$DEFAULT_HERMES_HOME/hermes-agent}"
DEFAULT_HERMES_BIN="${HERMES_DEFAULT_BIN:-$DEFAULT_HERMES_INSTALL_DIR/venv/bin/hermes}"

ANKH_HELP='ankh - Agent Ankh management CLI

Usage: ankh COMMAND

Commands:
  setup        Check the installed Ankh runtime, PATH readiness, and Hermes global setup
  uninstall    Remove deployed Ankh runtime/wrappers and optionally Hermes/data
  --help       Show this help

Examples:
  ankh setup       # Verify the installed Ankh runtime, PATH, and Hermes global setup
  ankh uninstall   # Remove Ankh runtime and choose whether to keep Hermes/data
'

log_info() { echo "$*"; }
log_warn() { echo "$*" >&2; }
log_error() { echo "$*" >&2; }

ensure_package_root() {
    if [[ ! -d "$PKG_ROOT/src/scripts" ]]; then
        log_error "ankh: package directory not found at $PKG_ROOT"
        log_error "Reinstall the ankh package and run bun bootstrap."
        exit 1
    fi
}

load_runtime_helper() {
    local helper="$PKG_ROOT/src/scripts/cli/runtime-state.sh"
    if [[ ! -f "$helper" ]]; then
        log_error "Agent Ankh package is incomplete."
        log_error "Missing runtime helper: $helper"
        log_error "Fix: bun bootstrap in the Ankh.md repository root."
        exit 1
    fi

    # shellcheck disable=SC1090
    source "$helper"
}

has_provider_keys_in_env() {
    [[ -n "${OPENROUTER_API_KEY:-}" ]] || [[ -n "${OPENAI_API_KEY:-}" ]] || [[ -n "${ANTHROPIC_API_KEY:-}" ]] || [[ -n "${OPENAI_BASE_URL:-}" ]]
}

has_provider_keys_in_file() {
    local env_file="$1"
    [[ -f "$env_file" ]] || return 1

    while IFS= read -r line; do
        line="${line%%#*}"
        if [[ "$line" == *=* ]]; then
            local key="${line%%=*}"
            key="${key// /}"
            if [[ "$key" == OPENROUTER_API_KEY ]] || [[ "$key" == OPENAI_API_KEY ]] || [[ "$key" == ANTHROPIC_API_KEY ]] || [[ "$key" == OPENAI_BASE_URL ]]; then
                local val="${line#*=}"
                val="${val// /}"
                val="${val%\"}"
                val="${val#\"}"
                if [[ -n "$val" ]]; then
                    return 0
                fi
            fi
        fi
    done < "$env_file"
    return 1
}

ankh_is_configured() {
    if has_provider_keys_in_env; then
        return 0
    fi
    if has_provider_keys_in_file "$DEFAULT_HERMES_HOME/.env"; then
        return 0
    fi
    [[ -f "$DEFAULT_HERMES_HOME/auth.json" ]]
}

prompt_yes_no() {
    local prompt="$1"
    local default_yes="${2:-yes}"
    local reply=""

    read -r -p "$prompt" reply || true
    reply="${reply:-}"
    if [[ -z "$reply" ]]; then
        [[ "$default_yes" == "yes" ]]
        return
    fi

    case "$reply" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        [Nn]|[Nn][Oo]) return 1 ;;
        *)
            log_warn "Please answer yes or no."
            prompt_yes_no "$prompt" "$default_yes"
            ;;
    esac
}

safe_remove_path() {
    local path="$1"
    [[ -n "$HOME" && "$HOME" != "/" ]] || return 0
    [[ -n "$path" ]] || return 0
    [[ -e "$path" || -L "$path" ]] || return 0

    case "$path" in
        "$HOME/.agent" | "$HOME/.agent"/* | "$HOME/.hermes" | "$HOME/.hermes"/*)
            rm -rf "$path"
            ;;
        *)
            log_warn "Refusing to remove unexpected path: $path"
            return 1
            ;;
    esac
}

remove_file_if_present() {
    local path="$1"
    [[ -n "$path" ]] || return 0
    if [[ -e "$path" || -L "$path" ]]; then
        rm -f "$path"
    fi
}

remove_shim_if_target() {
    local shim_path="$1"
    local expected_target="$2"
    [[ -L "$shim_path" ]] || return 0
    local actual_target
    actual_target="$(readlink "$shim_path" 2>/dev/null || true)"
    if [[ "$actual_target" == "$expected_target" ]]; then
        rm -f "$shim_path"
    fi
}

write_default_hermes_wrapper() {
    mkdir -p "$AGENT_BIN"
    cat > "$AGENT_BIN/hermes" <<EOF
#!/bin/bash
exec "$DEFAULT_HERMES_BIN" "\$@"
EOF
    chmod +x "$AGENT_BIN/hermes"
}

cleanup_global_shims() {
    local keep_hermes="$1"
    local hermes_wrapper_kept="$2"

    local gbin
    for gbin in "$HOME/.local/bin" /opt/homebrew/bin /usr/local/bin; do
        [[ -d "$gbin" ]] || continue
        remove_shim_if_target "$gbin/ankh" "$AGENT_BIN/ankh"
        remove_shim_if_target "$gbin/ankh-hermes" "$AGENT_BIN/ankh-hermes"
        if [[ "$keep_hermes" != "yes" || "$hermes_wrapper_kept" != "yes" ]]; then
            remove_shim_if_target "$gbin/hermes" "$AGENT_BIN/hermes"
        fi
    done
}

trim_empty_dirs() {
    rmdir "$AGENT_BIN" 2>/dev/null || true
    rmdir "$HOME/.agent" 2>/dev/null || true
}

cmd_setup() {
    ensure_package_root
    load_runtime_helper

    if ! ankh_validate_install_integrity "$PKG_ROOT" "$ANKH_HOME" "$AGENT_BIN" "$ANKH_RUNTIME_DIR"; then
        ankh_print_integrity_report
        exit 1
    fi

    if ! ankh_validate_active_hermes_path "$AGENT_BIN"; then
        ankh_print_path_report "$AGENT_BIN"
        exit 1
    fi

    if ankh_is_configured; then
        log_info ""
        log_info "Agent Ankh is set up and ready."
        log_info ""
        log_info "Next steps:"
        log_info "  - Run 'hermes' in a directory with .agent already set up"
        log_info "  - Run 'hermes ankh' for Ankh management & usage info"
        log_info ""
        log_info "Hermes Path: $DEFAULT_HERMES_HOME"
        log_info "Ankh.md Path: $ANKH_HOME"
        log_info ""
        exit 0
    fi

    log_info "Agent Ankh is installed but Hermes global setup is not yet ready."
    log_info "Hermes global home: $DEFAULT_HERMES_HOME"
    log_info "Ankh runtime home: $ANKH_HOME"
    if prompt_yes_no "Run Hermes global setup now? [Y/n] " "yes"; then
        HERMES_ANKH_SCOPE=global "$AGENT_BIN/hermes" setup
        exit $?
    fi
    log_info "When ready, run: HERMES_ANKH_SCOPE=global $AGENT_BIN/hermes setup"
    exit 1
}

do_uninstall_cleanup() {
    local keep_hermes="$1"
    local keep_ankh_data="$2"
    local keep_hermes_data="${3:-yes}"
    local hermes_wrapper_kept="no"

    safe_remove_path "$ANKH_RUNTIME_DIR"
    remove_file_if_present "$ANKH_HOME/install-state.env"
    remove_file_if_present "$AGENT_BIN/ankh"
    remove_file_if_present "$AGENT_BIN/ankh-hermes"

    if [[ "$keep_hermes" == "yes" ]] && [[ -x "$DEFAULT_HERMES_BIN" ]]; then
        write_default_hermes_wrapper
        hermes_wrapper_kept="yes"
        log_info "Kept Hermes via $DEFAULT_HERMES_BIN"
    else
        remove_file_if_present "$AGENT_BIN/hermes"
        if [[ "$keep_hermes" == "yes" ]]; then
            log_warn "Default Hermes not found at $DEFAULT_HERMES_BIN; removed $AGENT_BIN/hermes without replacement."
        fi
    fi

    cleanup_global_shims "$keep_hermes" "$hermes_wrapper_kept"

    if [[ "$keep_hermes" == "no" ]]; then
        safe_remove_path "$DEFAULT_HERMES_INSTALL_DIR"
        if [[ "$keep_hermes_data" == "no" ]]; then
            safe_remove_path "$DEFAULT_HERMES_HOME"
        fi
    fi

    if [[ "$keep_ankh_data" == "no" ]]; then
        safe_remove_path "$ANKH_HOME"
    fi

    trim_empty_dirs
}

cmd_uninstall() {
    local keep_hermes="yes"
    local keep_ankh_data="yes"
    local keep_hermes_data="yes"

    if [[ -n "${KEEP_HERMES:-}" ]]; then
        keep_hermes="${KEEP_HERMES}"
    else
        if ! prompt_yes_no "Keep Hermes? [Y/n] " "yes"; then
            keep_hermes="no"
        fi
    fi

    if [[ -n "${KEEP_ANKH_DATA:-}" ]]; then
        keep_ankh_data="${KEEP_ANKH_DATA}"
    else
        if ! prompt_yes_no "Keep Ankh global data? [Y/n] " "yes"; then
            keep_ankh_data="no"
        fi
    fi

    if [[ "$keep_hermes" == "no" ]]; then
        if [[ -n "${KEEP_HERMES_DATA:-}" ]]; then
            keep_hermes_data="${KEEP_HERMES_DATA}"
        else
            if ! prompt_yes_no "Keep Hermes global data? [Y/n] " "yes"; then
                keep_hermes_data="no"
            fi
        fi
    fi

    do_uninstall_cleanup "$keep_hermes" "$keep_ankh_data" "$keep_hermes_data"

    log_info "Agent Ankh uninstall complete."
    log_info "No project-local .agent folders were modified."
}

# Only run dispatch when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        setup)
            shift
            cmd_setup "$@"
            ;;
        uninstall)
            shift
            cmd_uninstall "$@"
            ;;
        --help|-h|"")
            echo "$ANKH_HELP"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "$ANKH_HELP"
            exit 1
            ;;
    esac
fi
