#!/bin/bash
# Shared Agent Ankh runtime helpers.

ANKH_INSTALL_STATE_FILE_NAME="${ANKH_INSTALL_STATE_FILE_NAME:-install-state.env}"
ANKH_PATCH_MARKER_RELATIVE="${ANKH_PATCH_MARKER_RELATIVE:-source/hermes_cli/config.py}"
ANKH_PATCH_MARKER_TEXT="${ANKH_PATCH_MARKER_TEXT:-def get_ankh_scope_root(}"
ANKH_PATCH_MARKER_TEXT_FALLBACK="${ANKH_PATCH_MARKER_TEXT_FALLBACK:-return get_ankh_scope_root() / \"gateway.json\"}"

ANKH_VALIDATION_ERRORS=()
ANKH_PATH_ERRORS=()

ankh_get_pkg_root() {
    if [[ -n "${AGENT_ANKH_PKG_ROOT:-}" ]]; then
        printf '%s\n' "$AGENT_ANKH_PKG_ROOT"
        return
    fi
    if [[ -n "${PKG_ROOT:-}" ]]; then
        printf '%s\n' "$PKG_ROOT"
        return
    fi
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    printf '%s\n' "$(cd "$script_dir/../../.." && pwd)"
}

ankh_get_home() {
    printf '%s\n' "${AGENT_ANKH_HOME:-$HOME/.agent/extensions/ankh}"
}

ankh_get_runtime_dir() {
    printf '%s\n' "${AGENT_ANKH_RUNTIME_DIR:-$(ankh_get_home)/runtime}"
}

ankh_get_agent_bin() {
    printf '%s\n' "${AGENT_BIN:-$HOME/.agent/extensions/ankh/bin}"
}

ankh_get_runtime_source_dir() {
    local runtime_dir="${1:-$(ankh_get_runtime_dir)}"
    printf '%s\n' "$runtime_dir/source"
}

ankh_get_runtime_python() {
    local runtime_dir="${1:-$(ankh_get_runtime_dir)}"
    printf '%s\n' "$runtime_dir/.venv/bin/python"
}

ankh_get_patch_marker_path() {
    local runtime_dir="${1:-$(ankh_get_runtime_dir)}"
    printf '%s\n' "$runtime_dir/$ANKH_PATCH_MARKER_RELATIVE"
}

ankh_clear_validation_errors() {
    ANKH_VALIDATION_ERRORS=()
}

ankh_clear_path_errors() {
    ANKH_PATH_ERRORS=()
}

ankh_add_validation_error() {
    ANKH_VALIDATION_ERRORS+=("$1")
}

ankh_add_path_error() {
    ANKH_PATH_ERRORS+=("$1")
}

ankh_get_enabled_patch_names() {
    local pkg_root="${1:-$(ankh_get_pkg_root)}"
    python3 - "$pkg_root/src/patches/config.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)

for section in ("core", "labs"):
    for name, entry in data.get(section, {}).items():
        if entry.get("enabled"):
            print(f"{section}/{name}")
PY
}

ankh_resolve_path() {
    local path="$1"
    python3 - "$path" <<'PY'
from pathlib import Path
import sys

print(Path(sys.argv[1]).resolve(strict=False))
PY
}

ankh_runtime_is_patched() {
    local marker_path="${1:-$(ankh_get_patch_marker_path)}"
    [[ -f "$marker_path" ]] || return 1
    grep -Fq "$ANKH_PATCH_MARKER_TEXT" "$marker_path" || return 1
    grep -Fq "$ANKH_PATCH_MARKER_TEXT_FALLBACK" "$marker_path" || return 1
}

ankh_exec_runtime() {
    local runtime_dir="${1:-$(ankh_get_runtime_dir)}"
    local runtime_python runtime_source
    runtime_python="$(ankh_get_runtime_python "$runtime_dir")"
    runtime_source="$(ankh_get_runtime_source_dir "$runtime_dir")"

    if [[ "$#" -gt 0 ]]; then
        shift
    fi

    if [[ ! -x "$runtime_python" ]]; then
        echo "Agent Ankh runtime is incomplete: missing Python runtime at $runtime_python" >&2
        return 1
    fi

    if [[ ! -d "$runtime_source" ]]; then
        echo "Agent Ankh runtime is incomplete: missing source bundle at $runtime_source" >&2
        return 1
    fi

    export PYTHONPATH="$runtime_source${PYTHONPATH:+:$PYTHONPATH}"
    exec "$runtime_python" -m hermes_cli.main "$@"
}

ankh_validate_install_integrity() {
    local pkg_root="${1:-$(ankh_get_pkg_root)}"
    local _ankh_home="${2:-$(ankh_get_home)}"
    local agent_bin="${3:-$(ankh_get_agent_bin)}"
    local runtime_dir="${4:-$(ankh_get_runtime_dir)}"
    local marker_path runtime_python runtime_source

    ankh_clear_validation_errors
    marker_path="$(ankh_get_patch_marker_path "$runtime_dir")"
    runtime_python="$(ankh_get_runtime_python "$runtime_dir")"
    runtime_source="$(ankh_get_runtime_source_dir "$runtime_dir")"

    if [[ ! -d "$pkg_root" ]]; then
        ankh_add_validation_error "Missing package root: $pkg_root"
        return 1
    fi
    if [[ ! -f "$pkg_root/src/scripts/cli/cli.sh" ]]; then
        ankh_add_validation_error "Missing package script: $pkg_root/src/scripts/cli/cli.sh"
    fi
    if [[ ! -f "$pkg_root/src/scripts/cli/runtime-state.sh" ]]; then
        ankh_add_validation_error "Missing runtime helper: $pkg_root/src/scripts/cli/runtime-state.sh"
    fi
    if [[ ! -d "$runtime_dir" ]]; then
        ankh_add_validation_error "Missing Ankh runtime directory: $runtime_dir"
    fi
    if [[ ! -x "$runtime_python" ]]; then
        ankh_add_validation_error "Missing runtime Python executable: $runtime_python"
    fi
    if [[ ! -d "$runtime_source" ]]; then
        ankh_add_validation_error "Missing runtime source bundle: $runtime_source"
    fi
    if [[ ! -f "$runtime_dir/help.md" ]]; then
        ankh_add_validation_error "Missing runtime help doc: $runtime_dir/help.md"
    fi
    if [[ ! -x "$agent_bin/ankh" ]]; then
        ankh_add_validation_error "Missing wrapper: $agent_bin/ankh"
    fi
    if [[ ! -x "$agent_bin/ankh-hermes" ]]; then
        ankh_add_validation_error "Missing wrapper: $agent_bin/ankh-hermes"
    fi
    if [[ ! -x "$agent_bin/hermes" ]]; then
        ankh_add_validation_error "Missing wrapper: $agent_bin/hermes"
    fi
    if [[ ! -f "$marker_path" ]]; then
        ankh_add_validation_error "Missing Ankh patch marker file: $marker_path"
    elif ! ankh_runtime_is_patched "$marker_path"; then
        ankh_add_validation_error "Installed Hermes runtime is not Ankh-patched: $marker_path"
    fi

    [[ "${#ANKH_VALIDATION_ERRORS[@]}" -eq 0 ]]
}

ankh_validate_active_hermes_path() {
    local agent_bin="${1:-$(ankh_get_agent_bin)}"
    local active_path expected_path resolved_active resolved_expected

    ankh_clear_path_errors
    expected_path="$agent_bin/hermes"
    active_path="$(command -v hermes 2>/dev/null || true)"

    if [[ -z "$active_path" ]]; then
        ankh_add_path_error "hermes is not on PATH"
        return 1
    fi

    resolved_active="$(ankh_resolve_path "$active_path")"
    resolved_expected="$(ankh_resolve_path "$expected_path")"

    if [[ "$resolved_active" != "$resolved_expected" ]]; then
        ankh_add_path_error "hermes resolves to $active_path"
        return 1
    fi

    return 0
}

ankh_print_integrity_report() {
    local heading="${1:-Agent Ankh runtime is missing or no longer patched.}"
    echo "$heading" >&2
    for issue in "${ANKH_VALIDATION_ERRORS[@]}"; do
        echo "  - $issue" >&2
    done
    echo "Run: bun bootstrap" >&2
}

ankh_print_path_report() {
    local agent_bin="${1:-$(ankh_get_agent_bin)}"
    echo "Agent Ankh runtime is healthy, but hermes is not ready on PATH." >&2
    for issue in "${ANKH_PATH_ERRORS[@]}"; do
        echo "  - $issue" >&2
    done
    echo "Expected: $agent_bin/hermes" >&2
    echo "Add to PATH: export PATH=\"\$HOME/.agent/extensions/ankh/bin:\$PATH\"" >&2
}

ankh_guard_deployed_runtime() {
    local heading="${1:-Agent Ankh runtime is missing or no longer patched.}"
    local pkg_root="${2:-$(ankh_get_pkg_root)}"
    local ankh_home="${3:-$(ankh_get_home)}"
    local agent_bin="${4:-$(ankh_get_agent_bin)}"
    local runtime_dir="${5:-$(ankh_get_runtime_dir)}"

    if ankh_validate_install_integrity "$pkg_root" "$ankh_home" "$agent_bin" "$runtime_dir"; then
        return 0
    fi

    ankh_print_integrity_report "$heading"
    return 1
}
