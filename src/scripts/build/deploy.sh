#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Agent Ankh Deploy Script
# ═══════════════════════════════════════════════════════════════════════════
# Copies build to ~/.agent/extensions/ankh/runtime and creates CLI wrappers in
# ~/.agent/extensions/ankh/bin without changing Hermes' native global home structure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="${PKG_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
BUILD_DIR="${BUILD_DIR:-$PKG_ROOT/.build}"
ANKH_HOME="${ANKH_HOME:-$HOME/.agent/extensions/ankh}"
INSTALL_DIR="${INSTALL_DIR:-$ANKH_HOME/runtime}"
AGENT_BIN="${AGENT_BIN:-$HOME/.agent/extensions/ankh/bin}"
log_step() { echo "[*] $*"; }
log_success() { echo "[✓] $*"; }
log_error() { echo "[✗] $*" >&2; }
log_info() { echo "    $*"; }

global_shims_enabled() {
    case "${ANKH_INSTALL_GLOBAL_SHIMS:-0}" in
        1|true|TRUE|yes|YES|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

write_agent_ankh_wrapper() {
    cat > "$AGENT_BIN/ankh" <<EOF
#!/bin/bash
set -euo pipefail
export AGENT_ANKH_PKG_ROOT="$INSTALL_DIR"
exec bash "$INSTALL_DIR/src/scripts/cli/cli.sh" "\$@"
EOF
    chmod +x "$AGENT_BIN/ankh"
}

write_hermes_ankh_wrapper() {
    cat > "$AGENT_BIN/ankh-hermes" <<EOF
#!/bin/bash
exec "$AGENT_BIN/hermes" ankh "\$@"
EOF
    chmod +x "$AGENT_BIN/ankh-hermes"
}

write_hermes_wrapper() {
    cat > "$AGENT_BIN/hermes" <<EOF
#!/bin/bash
set -euo pipefail
RUNTIME_HELPER="$INSTALL_DIR/src/scripts/cli/runtime-state.sh"
RUNTIME_DIR="$INSTALL_DIR"
AGENT_BIN_DIR="$AGENT_BIN"
ANKH_HOME_DIR="$ANKH_HOME"
DEFAULT_HERMES_BIN="\${HERMES_DEFAULT_BIN:-\${HOME}/.hermes/hermes-agent/venv/bin/hermes}"

load_runtime_helper() {
    if [[ ! -f "\$RUNTIME_HELPER" ]]; then
        echo "Agent Ankh install is stale or incomplete." >&2
        echo "  - Missing runtime helper: \$RUNTIME_HELPER" >&2
        echo "Run: bun bootstrap" >&2
        return 1
    fi

    # shellcheck disable=SC1090
    source "\$RUNTIME_HELPER"
}

guard_ankh_runtime() {
    local heading="\${1:-Agent Ankh install is stale or incomplete.}"
    load_runtime_helper || return 1
    ankh_guard_deployed_runtime "\$heading" "\$RUNTIME_DIR" "\$ANKH_HOME_DIR" "\$AGENT_BIN_DIR" "\$RUNTIME_DIR"
}

is_valid_agent_scope() {
    local dir="\$PWD"
    while [[ "\$dir" != "/" ]]; do
        if [[ -f "\$dir/.agent/config.yaml" ]]; then
            return 0
        fi
        dir="\$(dirname "\$dir")"
    done
    return 1
}

if [[ "\${1:-}" == "update" ]]; then
    echo "To update Hermes Ankh, run: bun bootstrap"
    exit 0
fi

if [[ "\${1:-}" == "uninstall" ]]; then
    exec "$AGENT_BIN/ankh" uninstall
fi

if [[ "\${1:-}" == "ankh" ]]; then
    shift
    exec "$AGENT_BIN/ankh" "\$@"
fi

if [[ "\${HERMES_ANKH_SCOPE:-}" == "global" ]]; then
    guard_ankh_runtime "Agent Ankh global runtime is stale or incomplete." || exit 1
    ankh_exec_runtime "\$RUNTIME_DIR" "\$@"
    exit \$?
fi

if is_valid_agent_scope; then
    guard_ankh_runtime "Agent Ankh scoped runtime is stale or incomplete." || exit 1
    ankh_exec_runtime "\$RUNTIME_DIR" "\$@"
    exit \$?
fi

if [[ -x "\$DEFAULT_HERMES_BIN" ]]; then
    exec "\$DEFAULT_HERMES_BIN" "\$@"
fi

echo "hermes: default Hermes not found at \$DEFAULT_HERMES_BIN" >&2
echo "Install default Hermes first: https://hermes-agent.nousresearch.com/" >&2
exit 1
EOF
    chmod +x "$AGENT_BIN/hermes"
}

create_global_shims() {
    local gbin
    local shim_dirs="${ANKH_GLOBAL_SHIM_DIRS:-/opt/homebrew/bin:/usr/local/bin}"

    IFS=':' read -r -a gbin_dirs <<<"$shim_dirs"
    for gbin in "${gbin_dirs[@]}"; do
        [[ -n "$gbin" ]] || continue
        if [[ -d "$gbin" ]]; then
            ln -sf "$AGENT_BIN/ankh" "$gbin/ankh" 2>/dev/null && log_success "Shim: $gbin/ankh" || true
            ln -sf "$AGENT_BIN/ankh-hermes" "$gbin/ankh-hermes" 2>/dev/null && log_success "Shim: $gbin/ankh-hermes" || true
            ln -sf "$AGENT_BIN/hermes" "$gbin/hermes" 2>/dev/null && log_success "Shim: $gbin/hermes" || true
        fi
    done
}

main() {
    echo "╔══════════════════════════════════════╗"
    echo "║    Agent Ankh Deploy                 ║"
    echo "╚══════════════════════════════════════╝"

    if [[ ! -d "$BUILD_DIR" || ! -x "$BUILD_DIR/.venv/bin/python" || ! -d "$BUILD_DIR/source" ]]; then
        log_error "Build not found. Run: bun run build"
        exit 1
    fi

    log_step "Copying build to $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cp -a "$BUILD_DIR/.venv" "$INSTALL_DIR/"
    cp -a "$BUILD_DIR/source" "$INSTALL_DIR/"
    cp -a "$PKG_ROOT/src" "$INSTALL_DIR/"
    log_step "Removing vendor .git from installed runtime..."
    find "$INSTALL_DIR" -type d -name ".git" -print0 2>/dev/null | xargs -0 rm -rf 2>/dev/null || true
    if [[ -f "$PKG_ROOT/src/resources/console/help.md" ]]; then
        cp "$PKG_ROOT/src/resources/console/help.md" "$INSTALL_DIR/"
    fi
    log_success "Installed to $INSTALL_DIR"

    log_step "Creating CLI wrappers..."
    mkdir -p "$AGENT_BIN"
    write_agent_ankh_wrapper
    log_success "ankh: $AGENT_BIN/ankh (primary)"
    write_hermes_ankh_wrapper
    log_success "ankh-hermes: $AGENT_BIN/ankh-hermes -> hermes ankh"
    write_hermes_wrapper
    log_success "hermes: $AGENT_BIN/hermes (ankh passthrough to ankh; patched in valid .agent; else default Hermes)"

    if global_shims_enabled; then
        log_step "Creating opt-in global shims..."
        create_global_shims
    else
        log_info "Global shims skipped by default; add $AGENT_BIN to PATH to use Ankh commands."
        log_info "Set ANKH_INSTALL_GLOBAL_SHIMS=1 to also create shims in /opt/homebrew/bin or /usr/local/bin."
    fi

    log_success "Agent Ankh deployed successfully!"
    log_info "Ankh asset home: $ANKH_HOME"
    log_info "Runtime: $INSTALL_DIR"
    log_info "Hermes global home remains: $HOME/.hermes"
    log_info "Commands: ankh (setup, uninstall), hermes ankh (passthrough to ankh), hermes"
    log_info "Binaries: $AGENT_BIN/ankh, $AGENT_BIN/ankh-hermes, $AGENT_BIN/hermes"
    echo ""
    log_info "Make sure you add Ankh.md to your system PATH."
    log_info "export PATH=\"\$HOME/.agent/extensions/ankh/bin:\$PATH\""
    echo ""
}

main "$@"
