#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Agent Ankh Test Assertions
# ═══════════════════════════════════════════════════════════════════════════
# Validates build, deploy, scoped behavior, uninstall flow, and tarball surface.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="${PKG_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
BUILD_DIR="${BUILD_DIR:-$PKG_ROOT/.build}"
ANKH_HOME="${ANKH_HOME:-$HOME/.agent/extensions/ankh}"
INSTALL_DIR="${INSTALL_DIR:-$ANKH_HOME/runtime}"
AGENT_BIN="${AGENT_BIN:-$HOME/.agent/extensions/ankh/bin}"
TARBALL_PATH="${TARBALL_PATH:-}"

# shellcheck disable=SC1091
source "$PKG_ROOT/src/scripts/cli/runtime-state.sh"

# Check if labs patches are enabled (auth, cron)
ankh_patch_enabled() {
    local patch_name="$1"
    python3 - "$PKG_ROOT/src/patches/config.json" "$patch_name" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
enabled = data.get("labs", {}).get(sys.argv[2], {}).get("enabled", False)
sys.exit(0 if enabled else 1)
PY
}

ok() { echo "✓ $*"; }
fail() { echo "✗ $*" >&2; exit 1; }

TMP_DIRS=()
cleanup() {
    for tmp in "${TMP_DIRS[@]:-}"; do
        [[ -n "$tmp" && -e "$tmp" ]] && rm -rf "$tmp" || true
    done
}
trap cleanup EXIT

make_temp_dir() {
    local tmp
    tmp="$(mktemp -d)"
    TMP_DIRS+=("$tmp")
    printf '%s\n' "$tmp"
}

make_default_hermes_stub() {
    local tmp_dir stub
    tmp_dir="$(make_temp_dir)"
    stub="$tmp_dir/hermes"
    cat > "$stub" <<'EOF'
#!/bin/bash
echo "default hermes stub"
exit 0
EOF
    chmod +x "$stub"
    printf '%s\n' "$stub"
}

seed_fake_default_hermes_install() {
    local home_dir="$1"
    local default_bin="$home_dir/.hermes/hermes-agent/venv/bin/hermes"
    mkdir -p "$(dirname "$default_bin")"
    cat > "$default_bin" <<'EOF'
#!/bin/bash
echo "default hermes install"
exit 0
EOF
    chmod +x "$default_bin"
    mkdir -p "$home_dir/.hermes"
    printf "model: anthropic/claude-sonnet-4\n" > "$home_dir/.hermes/config.yaml"
    printf '%s\n' "$default_bin"
}

seed_ready_hermes_global_state() {
    local home_dir="$1"
    mkdir -p "$home_dir/.hermes"
    cat > "$home_dir/.hermes/auth.json" <<'EOF'
{"version":1,"active_provider":"openrouter","providers":{"openrouter":{"api_key":"test-key"}}}
EOF
}

seed_fake_ankh_install() {
    local home_dir="$1"
    mkdir -p "$home_dir/.agent/extensions/ankh/runtime" "$home_dir/.agent/extensions/ankh/bin" "$home_dir/.local/bin"
    mkdir -p "$home_dir/.agent/extensions/ankh/runtime/.venv/bin"
    cat > "$home_dir/.agent/extensions/ankh/runtime/.venv/bin/python" <<'EOF'
#!/bin/bash
echo "patched hermes stub"
exit 0
EOF
    chmod +x "$home_dir/.agent/extensions/ankh/runtime/.venv/bin/python"
    mkdir -p "$(dirname "$home_dir/.agent/extensions/ankh/runtime/$ANKH_PATCH_MARKER_RELATIVE")"
    cat > "$home_dir/.agent/extensions/ankh/runtime/$ANKH_PATCH_MARKER_RELATIVE" <<'EOF'
def get_ankh_scope_root():
    pass

def get_gateway_config_path():
    return get_ankh_scope_root() / "gateway.json"
EOF
    printf "Ankh help\n" > "$home_dir/.agent/extensions/ankh/runtime/help.md"

    cat > "$home_dir/.agent/extensions/ankh/bin/ankh" <<'EOF'
#!/bin/bash
exit 0
EOF
    cat > "$home_dir/.agent/extensions/ankh/bin/ankh-hermes" <<'EOF'
#!/bin/bash
exit 0
EOF
    cat > "$home_dir/.agent/extensions/ankh/bin/hermes" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$home_dir/.agent/extensions/ankh/bin/ankh" "$home_dir/.agent/extensions/ankh/bin/ankh-hermes" "$home_dir/.agent/extensions/ankh/bin/hermes"
    ln -sf "$home_dir/.agent/extensions/ankh/bin/ankh" "$home_dir/.local/bin/ankh"
    ln -sf "$home_dir/.agent/extensions/ankh/bin/ankh-hermes" "$home_dir/.local/bin/ankh-hermes"
    ln -sf "$home_dir/.agent/extensions/ankh/bin/hermes" "$home_dir/.local/bin/hermes"
}

deploy_real_ankh_install() {
    local home_dir="$1"
    mkdir -p "$home_dir"
    HOME="$home_dir" BUILD_DIR="$BUILD_DIR" VENDOR_DIR="$PKG_ROOT" bash "$PKG_ROOT/src/scripts/build/deploy.sh" >/dev/null
}

assert_tarball_surface() {
    [[ -f "$TARBALL_PATH" ]] || fail "TARBALL_PATH not found: $TARBALL_PATH"

    local contents
    contents="$(tar -tzf "$TARBALL_PATH")" || fail "Could not inspect tarball contents"



    if grep -q '^package/bin/hermes$' <<<"$contents"; then
        fail "Tarball should not ship bin/hermes"
    fi
    if grep -q '^package/bin/ankh-hermes$' <<<"$contents"; then
        fail "Tarball should not ship bin/ankh-hermes"
    fi
    if grep -Eq '^package/examples/.*/\.agent/storage/state\.db(-shm|-wal)?$' <<<"$contents"; then
        fail "Tarball includes example SQLite state artifacts"
    fi
    if grep -Eq '^package/examples/.*/\.agent/skills/\.hub/' <<<"$contents"; then
        fail "Tarball includes skills hub cache artifacts"
    fi
    if grep -Eq '^package/examples/.*/\.agent/skills/\.bundled_manifest$' <<<"$contents"; then
        fail "Tarball includes bundled skills manifests"
    fi
    if grep -Eq '^package/examples/.*/\.agent/(auth\.json|processes\.json|modal_snapshots\.json|singularity_snapshots\.json)$' <<<"$contents"; then
        fail "Tarball includes scoped runtime state files"
    fi
    if grep -Eq '^package/.*__pycache__/.*$' <<<"$contents"; then
        fail "Tarball includes Python bytecode cache directories"
    fi
    if grep -Eq '^package/.*\.pyc$' <<<"$contents"; then
        fail "Tarball includes Python bytecode files"
    fi
    if grep -Eq '^package/.*\.DS_Store$' <<<"$contents"; then
        fail "Tarball includes macOS Finder artifacts"
    fi

    ok "Tarball surface OK"
}

assert_uninstall_keep_hermes() {
    local tmp_home tmp_project
    tmp_home="$(make_temp_dir)"
    tmp_project="$(make_temp_dir)"
    mkdir -p "$tmp_project/.agent"
    printf "model: anthropic/claude-sonnet-4\n" > "$tmp_project/.agent/config.yaml"

    deploy_real_ankh_install "$tmp_home"
    seed_fake_default_hermes_install "$tmp_home" >/dev/null

    HOME="$tmp_home" AGENT_ANKH_PKG_ROOT="$PKG_ROOT" KEEP_HERMES=yes KEEP_ANKH_DATA=yes KEEP_HERMES_DATA=yes "${tmp_home}/.agent/extensions/ankh/bin/ankh" uninstall >/dev/null

    [[ ! -e "$tmp_home/.agent/extensions/ankh/runtime" ]] || fail "Uninstall should remove Ankh runtime when keeping Hermes"
    [[ ! -e "$tmp_home/.agent/extensions/ankh/bin/ankh" ]] || fail "Uninstall should remove deployed ankh wrapper"
    [[ ! -e "$tmp_home/.agent/extensions/ankh/bin/ankh-hermes" ]] || fail "Uninstall should remove ankh-hermes wrapper"
    [[ ! -L "$tmp_home/.local/bin/ankh" ]] || fail "Uninstall should remove ankh shim"
    HOME="$tmp_home" "$tmp_home/.agent/extensions/ankh/bin/hermes" --help >/dev/null 2>&1 || fail "Uninstall should leave hermes pointing to default Hermes when kept"
    [[ -f "$tmp_project/.agent/config.yaml" ]] || fail "Uninstall must not touch project-local .agent folders"
    ok "Uninstall keeps Hermes and preserves Ankh data"
}

assert_uninstall_keep_data_drop_hermes() {
    local tmp_home tmp_project
    tmp_home="$(make_temp_dir)"
    tmp_project="$(make_temp_dir)"
    mkdir -p "$tmp_project/.agent"
    printf "model: anthropic/claude-sonnet-4\n" > "$tmp_project/.agent/config.yaml"

    deploy_real_ankh_install "$tmp_home"
    seed_fake_default_hermes_install "$tmp_home" >/dev/null

    HOME="$tmp_home" AGENT_ANKH_PKG_ROOT="$PKG_ROOT" KEEP_HERMES=no KEEP_ANKH_DATA=yes KEEP_HERMES_DATA=yes "${tmp_home}/.agent/extensions/ankh/bin/ankh" uninstall >/dev/null

    [[ ! -e "$tmp_home/.agent/extensions/ankh/runtime" ]] || fail "Uninstall should remove runtime when dropping Hermes"
    [[ ! -e "$tmp_home/.hermes/hermes-agent" ]] || fail "Uninstall should remove standard Hermes install tree when not keeping Hermes"
    [[ -f "$tmp_home/.hermes/config.yaml" ]] || fail "Uninstall should keep Hermes data when requested"
    [[ -f "$tmp_project/.agent/config.yaml" ]] || fail "Uninstall must not touch project-local .agent folders"
    ok "Uninstall drops Hermes runtime while preserving both data homes"
}

assert_uninstall_drop_all() {
    local tmp_home tmp_project
    tmp_home="$(make_temp_dir)"
    tmp_project="$(make_temp_dir)"
    mkdir -p "$tmp_project/.agent"
    printf "model: anthropic/claude-sonnet-4\n" > "$tmp_project/.agent/config.yaml"

    deploy_real_ankh_install "$tmp_home"
    seed_fake_default_hermes_install "$tmp_home" >/dev/null

    HOME="$tmp_home" AGENT_ANKH_PKG_ROOT="$PKG_ROOT" KEEP_HERMES=no KEEP_ANKH_DATA=no KEEP_HERMES_DATA=no "${tmp_home}/.agent/extensions/ankh/bin/ankh" uninstall >/dev/null

    [[ ! -e "$tmp_home/.agent/extensions/ankh" ]] || fail "Uninstall should remove Ankh home when not keeping Ankh data"
    [[ ! -e "$tmp_home/.agent/extensions/ankh/bin/hermes" ]] || fail "Uninstall should remove hermes wrapper when Hermes is not kept"
    [[ ! -e "$tmp_home/.hermes" ]] || fail "Uninstall should remove Hermes global data when not kept"
    [[ -f "$tmp_project/.agent/config.yaml" ]] || fail "Uninstall must not touch project-local .agent folders"
    ok "Uninstall drops Hermes and all global data"
}

assert_setup_requires_hermes_global_setup() {
    local tmp_home output
    tmp_home="$(make_temp_dir)"
    deploy_real_ankh_install "$tmp_home"

    if output="$(printf 'n\n' | HOME="$tmp_home" PATH="$tmp_home/.local/bin:$tmp_home/.agent/extensions/ankh/bin:$PATH" "$tmp_home/.agent/extensions/ankh/bin/ankh" setup 2>&1)"; then
        fail "ankh setup should fail when Hermes global setup is missing"
    fi

    grep -q "Agent Ankh is installed but Hermes global setup is not yet ready." <<<"$output" || fail "setup should report missing Hermes global setup"
    if grep -q "Run: bun bootstrap" <<<"$output"; then
        fail "setup should not report install drift when only Hermes global setup is missing"
    fi
    ok "Setup distinguishes healthy install from missing Hermes global setup"
}

assert_setup_ready_and_guarded_entrypoints() {
    local tmp_home tmp_scope output
    tmp_home="$(make_temp_dir)"
    tmp_scope="$(make_temp_dir)"
    deploy_real_ankh_install "$tmp_home"
    seed_fake_default_hermes_install "$tmp_home" >/dev/null
    seed_ready_hermes_global_state "$tmp_home"
    mkdir -p "$tmp_scope/.agent"
    printf "model: anthropic/claude-sonnet-4\n" > "$tmp_scope/.agent/config.yaml"

    output="$(HOME="$tmp_home" PATH="$tmp_home/.local/bin:$tmp_home/.agent/extensions/ankh/bin:$PATH" "$tmp_home/.agent/extensions/ankh/bin/ankh" setup 2>&1)" || fail "ankh setup should succeed when install and Hermes global state are ready"
    grep -q "Agent Ankh is set up and ready." <<<"$output" || fail "setup should report ready state"

    output="$(HOME="$tmp_home" PATH="$tmp_home/.local/bin:$tmp_home/.agent/extensions/ankh/bin:$PATH" "$tmp_home/.agent/extensions/ankh/bin/hermes" ankh 2>&1)" || fail "hermes ankh should succeed for healthy install"
    grep -q "Agent Ankh" <<<"$output" || fail "hermes ankh should render bundled docs"

    (cd "$tmp_scope" && HOME="$tmp_home" PATH="$tmp_home/.local/bin:$tmp_home/.agent/extensions/ankh/bin:$PATH" HERMES_DEFAULT_BIN=/usr/bin/false "$tmp_home/.agent/extensions/ankh/bin/hermes" --help >/dev/null 2>&1) || fail "scoped hermes should route to patched runtime when install is healthy"
    ok "Healthy setup and guarded entrypoints OK"
}

assert_unpatched_runtime_blocks() {
    local tmp_home tmp_scope output
    tmp_home="$(make_temp_dir)"
    tmp_scope="$(make_temp_dir)"
    deploy_real_ankh_install "$tmp_home"
    cat > "$tmp_home/.agent/extensions/ankh/runtime/$ANKH_PATCH_MARKER_RELATIVE" <<'EOF'
from pathlib import Path
EOF
    mkdir -p "$tmp_scope/.agent"
    printf "model: anthropic/claude-sonnet-4\n" > "$tmp_scope/.agent/config.yaml"

    if output="$(HOME="$tmp_home" PATH="$tmp_home/.local/bin:$tmp_home/.agent/extensions/ankh/bin:$PATH" "$tmp_home/.agent/extensions/ankh/bin/ankh" setup 2>&1)"; then
        fail "setup should fail when the deployed runtime is no longer patched"
    fi
    grep -q "Installed Hermes runtime is not Ankh-patched" <<<"$output" || fail "setup should report unpatched runtime"
    grep -q "Run: bun bootstrap" <<<"$output" || fail "setup should report repair command for unpatched runtime"

    if output="$(HOME="$tmp_home" PATH="$tmp_home/.local/bin:$tmp_home/.agent/extensions/ankh/bin:$PATH" "$tmp_home/.agent/extensions/ankh/bin/hermes" ankh setup 2>&1)"; then
        fail "hermes ankh setup should fail when the deployed runtime is no longer patched"
    fi
    grep -q "Installed Hermes runtime is not Ankh-patched" <<<"$output" || fail "hermes ankh setup should report unpatched runtime"

    if output="$(cd "$tmp_scope" && HOME="$tmp_home" PATH="$tmp_home/.local/bin:$tmp_home/.agent/extensions/ankh/bin:$PATH" "$tmp_home/.agent/extensions/ankh/bin/hermes" --help 2>&1)"; then
        fail "scoped hermes should fail when the deployed runtime is no longer patched"
    fi
    grep -q "Installed Hermes runtime is not Ankh-patched" <<<"$output" || fail "scoped hermes should report unpatched runtime"
    ok "Unpatched runtime blocks guarded entrypoints"
}

assert_setup_path_mismatch_reported() {
    local tmp_home fake_bin output
    tmp_home="$(make_temp_dir)"
    fake_bin="$tmp_home/path-shadow"
    deploy_real_ankh_install "$tmp_home"
    seed_ready_hermes_global_state "$tmp_home"
    mkdir -p "$fake_bin"
    cat > "$fake_bin/hermes" <<'EOF'
#!/bin/bash
echo "shadowed hermes"
exit 0
EOF
    chmod +x "$fake_bin/hermes"

    if output="$(HOME="$tmp_home" PATH="$fake_bin:$tmp_home/.local/bin:$tmp_home/.agent/extensions/ankh/bin:$PATH" "$tmp_home/.agent/extensions/ankh/bin/ankh" setup 2>&1)"; then
        fail "setup should fail when PATH resolves hermes elsewhere"
    fi
    grep -q "Agent Ankh runtime is healthy, but hermes is not ready on PATH." <<<"$output" || fail "setup should report PATH readiness problem"
    grep -q "hermes resolves to $fake_bin/hermes" <<<"$output" || fail "setup should report the active non-Ankh hermes path"
    grep -q "Add to PATH: export PATH=\"\$HOME/.agent/extensions/ankh/bin:\$PATH\"" <<<"$output" || fail "setup should report PATH fix guidance"
    if grep -q "Run: bun bootstrap" <<<"$output"; then
        fail "setup should not report install drift for a PATH mismatch"
    fi
    ok "PATH mismatch is reported separately from install drift"
}

if [[ -n "$TARBALL_PATH" ]]; then
    assert_tarball_surface
fi

if [[ -f "$BUILD_DIR/hermes" ]]; then
    "$BUILD_DIR/hermes" --help >/dev/null 2>&1 || fail "Build hermes --help failed"
    ok "Build hermes OK"

    if [[ -d "$BUILD_DIR/source" ]]; then
        git_count=$(find "$BUILD_DIR/source" -type d -name ".git" 2>/dev/null | wc -l)
        [[ "$git_count" -eq 0 ]] || fail "Build contains nested .git (found $git_count)"
        ok "Build has no nested .git"
    fi
else
    fail "Build not found. Run: bun run build"
fi

out="$("$BUILD_DIR/hermes" --help 2>&1)"
if grep -qi "minisweagent\|Terminal requirements check failed" <<<"$out"; then
    fail "minisweagent/terminal error spam in output"
fi
ok "No minisweagent startup error"

default_stub="$(make_default_hermes_stub)"

if [[ -x "$AGENT_BIN/ankh" ]]; then
    help_out="$("$AGENT_BIN/ankh" --help 2>&1)"
    grep -q "ankh" <<<"$help_out" || fail "ankh --help missing ankh"
    grep -q "setup" <<<"$help_out" || fail "ankh --help missing setup"
    grep -q "uninstall" <<<"$help_out" || fail "ankh --help missing uninstall"
    grep -q "ankh uninstall" <<<"$help_out" || fail "ankh --help missing uninstall example"
    ok "ankh OK (management CLI)"
fi
if [[ -x "$AGENT_BIN/ankh-hermes" ]]; then
    ankh_out="$("$AGENT_BIN/ankh-hermes" 2>&1)"
    grep -q . <<<"$ankh_out" || fail "ankh-hermes produced no output"
    ok "ankh-hermes OK (shows docs)"
fi
if [[ -x "$AGENT_BIN/hermes" ]]; then
    ankh_out="$("$AGENT_BIN/hermes" ankh 2>&1)"
    grep -q . <<<"$ankh_out" || fail "hermes ankh produced no output"
    ok "hermes ankh OK"
    HERMES_DEFAULT_BIN="$default_stub" "$AGENT_BIN/hermes" --help >/dev/null 2>&1 || fail "hermes --help failed"
    ok "hermes wrapper OK"
fi

if [[ -x "$AGENT_BIN/hermes" ]]; then
    HERMES_DEFAULT_BIN="$default_stub" "$AGENT_BIN/hermes" --help >/dev/null 2>&1 || fail "hermes fallback-to-default failed outside scope"
    ok "hermes fallback route OK (outside scope)"

    HERMES_DEFAULT_BIN=/usr/bin/false HERMES_ANKH_SCOPE=global "$AGENT_BIN/hermes" --help >/dev/null 2>&1 || fail "hermes global route failed with HERMES_ANKH_SCOPE=global"
    ok "hermes global route OK"

    tmp_scope="$(make_temp_dir)"
    mkdir -p "$tmp_scope/.agent"
    printf "model: anthropic/claude-sonnet-4\n" > "$tmp_scope/.agent/config.yaml"
    (cd "$tmp_scope" && HERMES_DEFAULT_BIN=/usr/bin/false "$AGENT_BIN/hermes" --help >/dev/null 2>&1) || fail "hermes scoped route failed (did not use patched runtime)"
    ok "hermes scoped route OK (valid .agent)"
fi

if [[ -x "$AGENT_BIN/hermes" ]]; then
    for shim in \
        "$HOME/.local/bin/ankh" \
        "$HOME/.local/bin/ankh-hermes" \
        "$HOME/.local/bin/hermes" \
        "/opt/homebrew/bin/ankh" \
        "/opt/homebrew/bin/ankh-hermes" \
        "/opt/homebrew/bin/hermes" \
        "/usr/local/bin/ankh" \
        "/usr/local/bin/ankh-hermes" \
        "/usr/local/bin/hermes"; do
        if [[ -L "$shim" ]] && [[ "$(readlink "$shim" 2>/dev/null || true)" == "$AGENT_BIN/"* ]]; then
            fail "Deploy should not create shim outside $AGENT_BIN by default (found $shim)"
        fi
    done
    ok "Deploy kept wrappers scoped to $AGENT_BIN"

    export PATH="$AGENT_BIN:$PATH"
    command -v ankh >/dev/null 2>&1 || fail "ankh not discoverable via command -v"
    command -v ankh-hermes >/dev/null 2>&1 || fail "ankh-hermes not discoverable via command -v"
    command -v hermes >/dev/null 2>&1 || fail "hermes not discoverable via command -v"
    ok "command -v discoverability OK"
fi

if [[ -d "$INSTALL_DIR" ]] && [[ -x "$INSTALL_DIR/.venv/bin/python" ]]; then
    [[ ! -e "$INSTALL_DIR/hermes" ]] || fail "Installed runtime should not ship standalone hermes binary"
    [[ ! -e "$INSTALL_DIR/bin" ]] || fail "Installed runtime should not ship nested runtime bin directory"

    git_count=$(find "$INSTALL_DIR" -type d -name ".git" 2>/dev/null | wc -l)
    [[ "$git_count" -eq 0 ]] || fail "Installed runtime contains nested .git (found $git_count)"
    ok "Installed runtime layout OK"
fi

if [[ -d "$BUILD_DIR/source" ]] && [[ -x "$BUILD_DIR/hermes" ]] && [[ -x "$BUILD_DIR/.venv/bin/python" ]]; then
    tmp_scope="$(make_temp_dir)"
    mkdir -p "$tmp_scope/.agent"
    printf "model: anthropic/claude-sonnet-4\ntoolsets: [web, file]\n" > "$tmp_scope/.agent/config.yaml"

    (cd "$tmp_scope" && HERMES_ANKH_SCOPE=global "$BUILD_DIR/hermes" --help >/dev/null 2>&1) || true
    (cd "$tmp_scope" && "$BUILD_DIR/hermes" --help >/dev/null 2>&1) || true

    expected_scope_root="$(cd "$tmp_scope" && pwd -P)"
    scoped_db_path="$(cd "$tmp_scope" && PYTHONPATH="$BUILD_DIR/source" "$BUILD_DIR/.venv/bin/python" -c "from hermes_state import DEFAULT_DB_PATH; print(DEFAULT_DB_PATH)")"
    [[ "$scoped_db_path" == "$expected_scope_root/.agent/storage/state.db" ]] || fail "Scoped DEFAULT_DB_PATH not in .agent/storage (got $scoped_db_path)"

    printf '{"mainframe":"hermes"}\n' > "$tmp_scope/.agent/agent.jsonc"
    ankh_db_path="$(cd "$tmp_scope" && PYTHONPATH="$BUILD_DIR/source" "$BUILD_DIR/.venv/bin/python" -c "from hermes_state import DEFAULT_DB_PATH; print(DEFAULT_DB_PATH)")"
    [[ "$ankh_db_path" == "$expected_scope_root/.agent/storage/state.db" ]] || fail "Strict storage DB path not enforced with agent.jsonc present (got $ankh_db_path)"

    config_toolsets="$(cd "$tmp_scope" && PYTHONPATH="$BUILD_DIR/source" "$BUILD_DIR/.venv/bin/python" -c "from hermes_cli.config import load_config; print(','.join(load_config().get('toolsets', [])))")"
    [[ "$config_toolsets" == "web,file" ]] || fail "config.yaml toolsets not honored (got $config_toolsets)"

    agent_uuid_title="$(cd "$tmp_scope" && PYTHONPATH="$BUILD_DIR/source" "$BUILD_DIR/.venv/bin/python" -c "
from hermes_cli.config import get_agent_identity
u, t = get_agent_identity()
print((u or '') + '::' + (t or ''))
")"
    agent_uuid="${agent_uuid_title%%::*}"
    agent_title="${agent_uuid_title#*::}"
    [[ -n "$agent_uuid" ]] || fail "get_agent_identity should return uuid in local scope (got empty)"
    [[ "$agent_uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]] || fail "agent.uuid should be valid UUID format (got $agent_uuid)"
    [[ "$agent_title" == "A Wandering Agent" ]] || fail "agent.title should default to 'A Wandering Agent' when missing (got $agent_title)"
    grep -q '"uuid"' "$tmp_scope/.agent/agent.jsonc" || fail "agent.uuid should be persisted to agent.jsonc"

    printf '{"mainframe":"openclaw","uuid":"00000000-0000-4000-8000-000000000001","title":"Test"}\n' > "$tmp_scope/.agent/agent.jsonc"
    (cd "$tmp_scope" && PYTHONPATH="$BUILD_DIR/source" "$BUILD_DIR/.venv/bin/python" -c "
from hermes_cli.config import get_agent_identity
try:
    get_agent_identity()
except ValueError as e:
    if 'openclaw' in str(e) and 'not supported' in str(e):
        exit(0)
    raise
exit(1)
") || fail "mainframe openclaw should be rejected with clear error"

    printf '{"mainframe":"hermes","uuid":"00000000-0000-4000-8000-000000000002","title":"Test"}\n' > "$tmp_scope/.agent/agent.jsonc"

    touch "$tmp_scope/.agent/state.db"
    legacy_db_path="$(cd "$tmp_scope" && PYTHONPATH="$BUILD_DIR/source" "$BUILD_DIR/.venv/bin/python" -c "from hermes_state import DEFAULT_DB_PATH; print(DEFAULT_DB_PATH)")"
    [[ "$legacy_db_path" == "$expected_scope_root/.agent/storage/state.db" ]] || fail "Strict storage DB path not enforced with legacy file present (got $legacy_db_path)"

    ok "Scope regression (state path + config toolsets + agent identity) OK"
fi

if [[ -d "$BUILD_DIR/source" ]] && [[ -x "$BUILD_DIR/.venv/bin/python" ]]; then
    tmp_home="$(make_temp_dir)"
    tmp_scope="$(make_temp_dir)"
    mkdir -p "$tmp_home/.hermes" "$tmp_scope/.agent"
    printf "model: anthropic/claude-sonnet-4\n" > "$tmp_home/.hermes/config.yaml"
    printf "model: anthropic/claude-sonnet-4\n" > "$tmp_scope/.agent/config.yaml"

    (cd "$tmp_scope" && HOME="$tmp_home" PYTHONPATH="$BUILD_DIR/source" "$BUILD_DIR/.venv/bin/python" -c "
import sys
sys.path.insert(0, \"$BUILD_DIR/source\")
from cli import save_config_value
ok = save_config_value('agent.system_prompt', 'scoped prompt test')
sys.exit(0 if ok else 1)
") || fail "/prompt save_config_value failed in scoped run"

    grep -q "scoped prompt test" "$tmp_scope/.agent/config.yaml" || fail "/prompt did not write to .agent/config.yaml"
    ! grep -q "scoped prompt test" "$tmp_home/.hermes/config.yaml" 2>/dev/null || fail "/prompt should not write to ~/.hermes/config.yaml when scoped"
    ok "/prompt persistence (scoped .agent/config.yaml) OK"
fi

if [[ -d "$BUILD_DIR/source" ]] && [[ -x "$BUILD_DIR/.venv/bin/python" ]]; then
    tmp_home="$(make_temp_dir)"
    tmp_scope="$(make_temp_dir)"
    mkdir -p "$tmp_home/.hermes" "$tmp_scope/.agent"
    printf "model: anthropic/claude-sonnet-4\n" > "$tmp_home/.hermes/config.yaml"
    printf "model: anthropic/claude-sonnet-4\n" > "$tmp_scope/.agent/config.yaml"

    # cat > "$tmp_home/.hermes/auth.json" <<'EOF'
# {"version":1,"active_provider":"openrouter","providers":{"openrouter":{"api_key":"global-openrouter"}}}
# EOF
    # cat > "$tmp_scope/.agent/auth.json" <<'EOF'
# {"version":1,"active_provider":"nous","providers":{"nous":{"agent_key":"local-nous"}}}
# EOF
# 
    # mapfile -t auth_lines < <(
        # cd "$tmp_scope" &&
        # TMP_SCOPE="$tmp_scope" HOME="$tmp_home" PYTHONPATH="$BUILD_DIR/source" "$BUILD_DIR/.venv/bin/python" - <<'PY'
# import json
# import os
# from pathlib import Path
# from hermes_cli.auth import _auth_file_path, _load_auth_store, _save_auth_store, get_active_provider, get_provider_auth_state
# 
# store = _load_auth_store()
# print(_auth_file_path())
# print(get_active_provider() or "")
# print(",".join(sorted(store.get("providers", {}).keys())))
# print(store.get("providers", {}).get("openrouter", {}).get("api_key", ""))
# print((get_provider_auth_state("nous") or {}).get("agent_key", ""))
# _save_auth_store({"version": 1, "active_provider": "nous", "providers": {"nous": {"agent_key": "local-write"}}})
# local_auth = Path(os.environ["TMP_SCOPE"]) / ".agent" / "auth.json"
# print(json.loads(local_auth.read_text())["providers"]["nous"]["agent_key"])
# PY
    # )
# 
    # expected_auth="$(cd "$tmp_scope" && pwd -P)/.agent/auth.json"
    # actual_auth="$(cd "$(dirname "${auth_lines[0]}")" && pwd -P)/auth.json"
    # # [[ "$actual_auth" == "$expected_auth" ]] || fail "Scoped auth writes should target .agent/auth.json (got ${auth_lines[0]})"
    # [[ "${auth_lines[1]}" == "nous" ]] || fail "Active provider should prefer local auth (got ${auth_lines[1]})"
    # # [[ "${auth_lines[2]}" == "nous,openrouter" ]] || fail "Auth providers should merge global and local stores (got ${auth_lines[2]})"
    # [[ "${auth_lines[3]}" == "global-openrouter" ]] || fail "Merged auth store should retain global provider state"
    # [[ "${auth_lines[4]}" == "local-nous" ]] || fail "Merged auth store should expose local provider state"
    # [[ "${auth_lines[5]}" == "local-write" ]] || fail "Auth save should write to scoped .agent/auth.json"
    # ok "Auth scoping OK"
fi

if [[ -d "$BUILD_DIR/source" ]] && [[ -x "$BUILD_DIR/.venv/bin/python" ]]; then
    tmp_home="$(make_temp_dir)"
    tmp_scope="$(make_temp_dir)"
    mkdir -p "$tmp_home/.hermes" "$tmp_home/.hermes/skills" "$tmp_home/.hermes/memories"
    mkdir -p "$tmp_scope/.agent" "$tmp_scope/.agent/skills"
    printf "model: anthropic/claude-sonnet-4\n" > "$tmp_home/.hermes/config.yaml"
    printf "model: anthropic/claude-sonnet-4\n" > "$tmp_scope/.agent/config.yaml"
    printf "Global soul\n" > "$tmp_home/.hermes/SOUL.md"
    printf "Local scoped soul\n" > "$tmp_scope/.agent/SOUL.md"

    mapfile -t skill_lines < <(
        cd "$tmp_scope" &&
        HOME="$tmp_home" PYTHONPATH="$BUILD_DIR/source" "$BUILD_DIR/.venv/bin/python" - <<'PY'
from agent.prompt_builder import build_context_files_prompt
from tools.memory_tool import MEMORY_DIR
from tools.skills_hub import HUB_DIR
from tools.skills_tool import SKILLS_DIR

prompt = build_context_files_prompt()
print(MEMORY_DIR)
print(SKILLS_DIR)
print(HUB_DIR)
print("local" if "Local scoped soul" in prompt and "Global soul" not in prompt else "bad")
PY
    )

    scope_resolved="$(cd "$tmp_scope" && pwd -P)"
    [[ "${skill_lines[0]}" == "$scope_resolved/.agent/memories" ]] || fail "Memory dir should scope to .agent/memories (got ${skill_lines[0]})"
    [[ "${skill_lines[1]}" == "$scope_resolved/.agent/skills" ]] || fail "Skills dir should scope to .agent/skills (got ${skill_lines[1]})"
    [[ "${skill_lines[2]}" == "$scope_resolved/.agent/skills/.hub" ]] || fail "Skills hub dir should scope to .agent/skills/.hub (got ${skill_lines[2]})"
    [[ "${skill_lines[3]}" == "local" ]] || fail "SOUL.md prompt loading should prefer local scoped file"
    ok "Skills, memory, and SOUL.md scoping OK"
fi

if [[ -d "$BUILD_DIR/source" ]] && [[ -x "$BUILD_DIR/.venv/bin/python" ]] && ankh_patch_enabled "cron"; then
    tmp_home="$(make_temp_dir)"
    tmp_scope="$(make_temp_dir)"
    mkdir -p "$tmp_home/.hermes" "$tmp_scope/.agent"
    printf "model: anthropic/claude-sonnet-4\n" > "$tmp_home/.hermes/config.yaml"
    printf "model: anthropic/claude-sonnet-4\n" > "$tmp_scope/.agent/config.yaml"

    mapfile -t runtime_lines < <(
        cd "$tmp_scope" &&
        HOME="$tmp_home" PYTHONPATH="$BUILD_DIR/source" "$BUILD_DIR/.venv/bin/python" - <<'PY'
from cron.jobs import CRON_DIR
from gateway.channel_directory import DIRECTORY_PATH
from gateway.config import GatewayConfig
from gateway.hooks import HOOKS_DIR
from gateway.pairing import PAIRING_DIR
from gateway.platforms.base import AUDIO_CACHE_DIR, DOCUMENT_CACHE_DIR, IMAGE_CACHE_DIR
from tools.environments.base import get_sandbox_dir
from tools.environments.modal import _SNAPSHOT_STORE as MODAL_SNAPSHOT_STORE
from tools.environments.singularity import _SNAPSHOT_STORE as SINGULARITY_SNAPSHOT_STORE
from tools.process_registry import CHECKPOINT_PATH
from tools.tts_tool import DEFAULT_OUTPUT_DIR

print(CRON_DIR)
print(GatewayConfig().sessions_dir)
print(DIRECTORY_PATH)
print(HOOKS_DIR)
print(PAIRING_DIR)
print(AUDIO_CACHE_DIR)
print(DOCUMENT_CACHE_DIR)
print(IMAGE_CACHE_DIR)
print(CHECKPOINT_PATH)
print(DEFAULT_OUTPUT_DIR)
print(get_sandbox_dir())
print(MODAL_SNAPSHOT_STORE)
print(SINGULARITY_SNAPSHOT_STORE)
PY
    )

    scope_resolved="$(cd "$tmp_scope" && pwd -P)"
    [[ "${runtime_lines[0]}" == "$scope_resolved/.agent/cron" ]] || fail "CRON_DIR should scope to .agent/cron"
    [[ "${runtime_lines[1]}" == "$scope_resolved/.agent/sessions" ]] || fail "Gateway sessions_dir should scope to .agent/sessions"
    [[ "${runtime_lines[2]}" == "$scope_resolved/.agent/channel_directory.json" ]] || fail "Channel directory should scope to .agent/channel_directory.json"
    [[ "${runtime_lines[3]}" == "$scope_resolved/.agent/hooks" ]] || fail "Hooks dir should scope to .agent/hooks"
    [[ "${runtime_lines[4]}" == "$scope_resolved/.agent/pairing" ]] || fail "Pairing dir should scope to .agent/pairing"
    [[ "${runtime_lines[5]}" == "$scope_resolved/.agent/audio_cache" ]] || fail "Audio cache should scope to .agent/audio_cache"
    [[ "${runtime_lines[6]}" == "$scope_resolved/.agent/document_cache" ]] || fail "Document cache should scope to .agent/document_cache"
    [[ "${runtime_lines[7]}" == "$scope_resolved/.agent/image_cache" ]] || fail "Image cache should scope to .agent/image_cache"
    [[ "${runtime_lines[8]}" == "$scope_resolved/.agent/processes.json" ]] || fail "Process registry should scope to .agent/processes.json"
    [[ "${runtime_lines[9]}" == "$scope_resolved/.agent/audio_cache" ]] || fail "TTS output dir should scope to .agent/audio_cache"
    [[ "${runtime_lines[10]}" == "$scope_resolved/.agent/sandboxes" ]] || fail "Sandbox dir should scope to .agent/sandboxes"
    [[ "${runtime_lines[11]}" == "$scope_resolved/.agent/modal_snapshots.json" ]] || fail "Modal snapshots should scope to .agent/modal_snapshots.json"
    [[ "${runtime_lines[12]}" == "$scope_resolved/.agent/singularity_snapshots.json" ]] || fail "Singularity snapshots should scope to .agent/singularity_snapshots.json"
    ok "Gateway, cron, and runtime outlier scoping OK"
fi

assert_uninstall_keep_hermes
assert_uninstall_keep_data_drop_hermes
assert_uninstall_drop_all
assert_setup_requires_hermes_global_setup
assert_setup_ready_and_guarded_entrypoints
assert_unpatched_runtime_blocks
assert_setup_path_mismatch_reported
