#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Agent Ankh Install Script
# ═══════════════════════════════════════════════════════════════════════════
# Clones Hermes source, applies patches. Version and paths from vendor.json.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="${PKG_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

log_step() { echo "[*] $*"; }
log_success() { echo "[✓] $*"; }
log_error() { echo "[✗] $*" >&2; }
log_info() { echo "    $*"; }

# shellcheck disable=SC1091
source "$PKG_ROOT/src/scripts/cli/runtime-state.sh"
# shellcheck disable=SC1091
source "$PKG_ROOT/src/scripts/cli/vendor-load.sh"

VERSION="${VERSION:-$VENDOR_VERSION}"
GIT_REPO_URL="${GIT_REPO_URL:-$VENDOR_SOURCE_URL}"
CLONE_BRANCH="${CLONE_BRANCH:-$VENDOR_SOURCE_BRANCH}"
PATCHES_DIR="${PATCHES_DIR:-$VENDOR_PATCHES_DIR}"

if [[ -n "${CACHE_DIR:-}" ]]; then
    CACHE_DIR="$CACHE_DIR"
elif [[ "${FRESH_CACHE:-0}" == "1" ]]; then
    CACHE_DIR="$PKG_ROOT/.build/cache/${VERSION}-$(date +%Y%m%d%H%M%S)-$$"
    USED_FRESH_CACHE=1
else
    CACHE_DIR="${CACHE_DIR:-$VENDOR_CACHE_DIR}"
fi
mkdir -p "$(dirname "$CACHE_DIR")"

patch_hash_for() {
    local patch_file="$1"
    if command -v shasum &>/dev/null; then
        shasum -a 256 "$patch_file" 2>/dev/null | cut -d' ' -f1
        return
    fi
    if command -v sha256sum &>/dev/null; then
        sha256sum "$patch_file" 2>/dev/null | cut -d' ' -f1
        return
    fi
    return 1
}

write_patch_marker() {
    local patch_marker="$1"
    local patch_hash="${2:-}"
    if [[ -n "$patch_hash" ]]; then
        printf '%s\n' "$patch_hash" > "$patch_marker"
    else
        touch "$patch_marker"
    fi
}

run_patch_hook() {
    local patch_name="$1"
    case "$patch_name" in
        directory)
            log_step "Applying agent identity (get_agent_identity)..."
            if python3 "$PKG_ROOT/src/scripts/patch/identity.py" "$CACHE_DIR/hermes_cli/config.py"; then
                log_success "Agent identity applied"
            fi
            ;;
        banner)
            log_step "Applying inline serpent (Ankh mode)..."
            if python3 "$PKG_ROOT/src/scripts/patch/banner.py" "$CACHE_DIR/cli.py" "$CACHE_DIR/hermes_cli/banner.py"; then
                log_success "Inline serpent applied"
            fi
            ;;
        skills)
            # No extra hooks - skills.patch provides scoped SKILLS_DIR
            ;;
    esac
}

apply_patch_file() {
    local patch_path="$1"
    local patch_name="${patch_path##*/}"
    local patch_file="$PATCHES_DIR/${patch_path}.patch"
    local patch_marker="$CACHE_DIR/.patches_applied_${patch_path//\//_}"
    local patch_hash=""
    local marker_hash=""

    if [[ ! -f "$patch_file" ]]; then
        return
    fi

    patch_hash="$(patch_hash_for "$patch_file" || true)"
    [[ -f "$patch_marker" ]] && marker_hash="$(cat "$patch_marker" 2>/dev/null)"

    if [[ -n "$patch_hash" ]] && [[ "$marker_hash" == "$patch_hash" ]]; then
        log_info "${patch_path}.patch already applied (hash match)"
        return
    fi

    if git apply --check "$patch_file" 2>/dev/null; then
        git apply "$patch_file"
        write_patch_marker "$patch_marker" "$patch_hash"
        log_success "Applied ${patch_path}.patch"
        run_patch_hook "$patch_name"
        return
    fi

    if git apply --reverse --check "$patch_file" 2>/dev/null; then
        write_patch_marker "$patch_marker" "$patch_hash"
        log_info "${patch_path}.patch already present in source"
        run_patch_hook "$patch_name"
        return
    fi

    log_error "Patch ${patch_path}.patch failed against $CACHE_DIR"
    log_info "Use a fresh CACHE_DIR (or set FRESH_CACHE=1) for a clean install."
    exit 1
}

main() {
    echo "╔══════════════════════════════════════╗"
    echo "║    Agent Ankh Install                ║"
    echo "╚══════════════════════════════════════╝"

    log_step "Using Hermes Agent version: $VERSION"

    log_step "Cloning Hermes Agent source from GitHub..."
    mkdir -p "$(dirname "$CACHE_DIR")"
    # When using default path, always remove existing cache for a fresh clone
    if [[ -d "$CACHE_DIR" ]]; then
        if [[ "${CACHE_DIR}" == "$VENDOR_CACHE_DIR" ]]; then
            log_info "Removing existing cache for fresh clone..."
            chmod -R u+rwx "$CACHE_DIR" 2>/dev/null || true
            if ! /bin/rm -rf "$CACHE_DIR" 2>/dev/null; then
                tmp_remove="$(dirname "$CACHE_DIR")/.cache.removing.$$"
                mv "$CACHE_DIR" "$tmp_remove" && /bin/rm -rf "$tmp_remove" 2>/dev/null || true
            fi
            [[ -d "$CACHE_DIR" ]] && { log_error "Could not remove $CACHE_DIR. Delete it manually and retry."; exit 1; }
        else
            log_info "Hermes Agent source already exists at $CACHE_DIR (CACHE_DIR set explicitly)"
        fi
    fi
    if [[ ! -d "$CACHE_DIR" ]]; then
        if ! git clone --depth 1 --recurse-submodules --shallow-submodules --branch "$CLONE_BRANCH" "$GIT_REPO_URL" "$CACHE_DIR" 2>/dev/null; then
            if ! git clone --depth 1 --branch "$CLONE_BRANCH" "$GIT_REPO_URL" "$CACHE_DIR" 2>/dev/null; then
                git clone --depth 1 "$GIT_REPO_URL" "$CACHE_DIR" || {
                    log_error "The clone process failed"
                    exit 1
                }
            fi
            (cd "$CACHE_DIR" && git submodule update --init --depth 1)
        fi
        log_success "Cloned to $CACHE_DIR"
    fi

    log_step "Applying Ankh mods to the cloned Hermes Agent source..."
    cd "$CACHE_DIR"
    while IFS= read -r patch_path; do
        [[ -n "$patch_path" ]] || continue
        apply_patch_file "$patch_path"
    done < <(ankh_get_enabled_patch_names "$PKG_ROOT")
    cd - >/dev/null

    # When using a fresh timestamped cache, copy patched source to VENDOR_CACHE_DIR
    # so the build uses it (build expects VENDOR_CACHE_DIR)
    if [[ "$CACHE_DIR" != "$VENDOR_CACHE_DIR" ]]; then
        rm -rf "$VENDOR_CACHE_DIR"
        cp -a "$CACHE_DIR" "$VENDOR_CACHE_DIR"
        [[ "${USED_FRESH_CACHE:-0}" == "1" ]] && rm -rf "$CACHE_DIR"
        log_info "Synced patched source to $VENDOR_CACHE_DIR"
    fi

    log_success "Ankh.md local project installation complete!"
    log_info "Source: $VENDOR_CACHE_DIR"
    log_info "Next: bun run build && bun run deploy, or bun bootstrap for full setup."
}

main "$@"
