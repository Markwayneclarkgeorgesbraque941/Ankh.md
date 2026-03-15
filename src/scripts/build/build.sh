#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Agent Ankh Build Script
# ═══════════════════════════════════════════════════════════════════════════
# Creates venv and installs patched Hermes into .build. Paths from vendor.json.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="${PKG_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

log_step() { echo "[*] $*"; }
log_success() { echo "[✓] $*"; }
log_error() { echo "[✗] $*" >&2; }
log_info() { echo "    $*"; }

# shellcheck disable=SC1091
source "$PKG_ROOT/src/scripts/cli/vendor-load.sh"

CACHE_DIR="${CACHE_DIR:-$VENDOR_CACHE_DIR}"
BUILD_DIR="${BUILD_DIR:-$VENDOR_BUILD_DIR}"

if ! command -v python3 &>/dev/null && ! command -v python &>/dev/null; then
    log_error "Python 3.11+ required. Install Python first."
    exit 1
fi

main() {
    echo "╔══════════════════════════════════════╗"
    echo "║     Agent Ankh Build                 ║"
    echo "╚══════════════════════════════════════╝"

    if [[ ! -d "$CACHE_DIR" ]]; then
        log_error "Source not found. Run: bun install"
        exit 1
    fi

    rm -rf "$BUILD_DIR/.venv" "$BUILD_DIR/source" "$BUILD_DIR/hermes"
    mkdir -p "$BUILD_DIR"

    log_step "Creating virtual environment (standalone, non-editable)..."
    cd "$BUILD_DIR"
    if command -v uv &>/dev/null; then
        uv venv .venv
        uv pip install "$CACHE_DIR" --python .venv
    else
        python3 -m venv .venv
        .venv/bin/pip install "$CACHE_DIR"
    fi
    log_success "Hermes installed in venv (dependencies ready)"

    log_step "Bundling patched source for runtime imports..."
    rm -rf "$BUILD_DIR/source"
    mkdir -p "$BUILD_DIR/source"
    cp -a "$CACHE_DIR"/. "$BUILD_DIR/source"/
    log_step "Removing vendor .git from bundled source..."
    find "$BUILD_DIR/source" -type d -name ".git" -print0 2>/dev/null | xargs -0 rm -rf 2>/dev/null || true
    log_success "Patched source bundled in build output"

    log_step "Creating entry point..."
    cat > "$BUILD_DIR/hermes" << 'HERMES_EOF'
#!/bin/bash
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PYTHONPATH="$INSTALL_DIR/source${PYTHONPATH:+:$PYTHONPATH}"
exec "$INSTALL_DIR/.venv/bin/python" -m hermes_cli.main "$@"
HERMES_EOF
    chmod +x "$BUILD_DIR/hermes"
    log_success "Entry point created"

    mkdir -p "$BUILD_DIR/bin"
    cat > "$BUILD_DIR/bin/hermes" << 'BIN_HERMES_EOF'
#!/bin/bash
BIN_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME_ROOT="$(cd "$BIN_DIR/.." && pwd)"
exec "$RUNTIME_ROOT/hermes" "$@"
BIN_HERMES_EOF
    chmod +x "$BUILD_DIR/bin/hermes"
    cat > "$BUILD_DIR/bin/ankh" << 'AGENT_ANKH_EOF'
#!/bin/bash
RUNTIME_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export AGENT_ANKH_PKG_ROOT="$RUNTIME_ROOT"
exec bash "$RUNTIME_ROOT/src/scripts/cli/cli.sh" "$@"
AGENT_ANKH_EOF
    chmod +x "$BUILD_DIR/bin/ankh"
    cat > "$BUILD_DIR/bin/ankh-hermes" << 'HERMES_ANKH_EOF'
#!/bin/bash
exec "$(dirname "$0")/hermes" ankh "$@"
HERMES_ANKH_EOF
    chmod +x "$BUILD_DIR/bin/ankh-hermes"

    echo ""
    log_success "Agent Ankh build complete!"
    log_info "Build: $BUILD_DIR"
    log_info "Next: bun run deploy"
    echo ""
}

main "$@"
