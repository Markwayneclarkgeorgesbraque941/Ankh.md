#!/bin/bash
# Run a clean local-tarball installation validation in isolated directories.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="${PKG_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
TMP_ROOT="${TMP_ROOT:-$(mktemp -d)}"
KEEP_TMP="${KEEP_TMP:-0}"

cleanup() {
    if [[ "$KEEP_TMP" != "1" ]]; then
        rm -rf "$TMP_ROOT"
    fi
}
trap cleanup EXIT

HOME="$TMP_ROOT/home"
CACHE_DIR="$TMP_ROOT/.build/cache"
BUILD_DIR="$TMP_ROOT/.build"
RESOLVED_FILE="$TMP_ROOT/resolved"

mkdir -p "$HOME"

echo "[*] Tarball E2E temp root: $TMP_ROOT"
# Pack from a clean copy (exclude artifacts that must not ship) so tarball passes surface check
PKG_COPY="$TMP_ROOT/pkg-copy"
cp -a "$PKG_ROOT" "$PKG_COPY"
find "$PKG_COPY/examples" -type f \( -name "state.db" -o -name "state.db-shm" -o -name "state.db-wal" \) -delete 2>/dev/null || true
find "$PKG_COPY/examples" -type d -name ".hub" -path "*/.agent/skills/*" -exec rm -rf {} + 2>/dev/null || true
find "$PKG_COPY/examples" -type f -name ".bundled_manifest" -path "*/.agent/skills/*" -delete 2>/dev/null || true
find "$PKG_COPY/examples" -type f \( -name "auth.json" -o -name "processes.json" -o -name "modal_snapshots.json" -o -name "singularity_snapshots.json" \) -path "*/.agent/*" -delete 2>/dev/null || true
find "$PKG_COPY" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$PKG_COPY" -type f \( -name ".DS_Store" -o -name "*.pyc" \) -delete 2>/dev/null || true
tarball_name="$(cd "$PKG_COPY" && npm pack --silent)"
tarball_path="$TMP_ROOT/$tarball_name"
mv "$PKG_COPY/$tarball_name" "$tarball_path"

# Unpack tarball, install deps, run install/build/deploy
tar -xzf "$tarball_path" -C "$TMP_ROOT"
PACKAGE_ROOT="$TMP_ROOT/package"
cd "$PACKAGE_ROOT"
bun install
HOME="$HOME" CACHE_DIR="$CACHE_DIR" BUILD_DIR="$BUILD_DIR" bash src/scripts/build/install.sh
HOME="$HOME" CACHE_DIR="$CACHE_DIR" BUILD_DIR="$BUILD_DIR" bash src/scripts/build/build.sh
HOME="$HOME" CACHE_DIR="$CACHE_DIR" BUILD_DIR="$BUILD_DIR" bash src/scripts/build/deploy.sh

[[ ! -e "$HOME/.agent/extensions/ankh/runtime/hermes" ]] || { echo "[✗] deploy should not create runtime/hermes" >&2; exit 1; }
[[ ! -e "$HOME/.agent/extensions/ankh/runtime/bin" ]] || { echo "[✗] deploy should not create runtime/bin" >&2; exit 1; }

mkdir -p "$HOME/.hermes"
cat > "$HOME/.hermes/auth.json" <<'EOF'
{"version":1,"active_provider":"openrouter","providers":{"openrouter":{"api_key":"test-key"}}}
EOF

PATH="$HOME/.agent/extensions/ankh/bin:$PATH" HOME="$HOME" CACHE_DIR="$CACHE_DIR" BUILD_DIR="$BUILD_DIR" RESOLVED_FILE="$RESOLVED_FILE" "$HOME/.agent/extensions/ankh/bin/ankh" setup
HOME="$HOME" BUILD_DIR="$BUILD_DIR" TARBALL_PATH="$tarball_path" bash "$PACKAGE_ROOT/src/scripts/test/assertions.sh"

mkdir -p "$HOME/.hermes/hermes-agent/venv/bin"
cat > "$HOME/.hermes/hermes-agent/venv/bin/hermes" <<'EOF'
#!/bin/bash
echo "default hermes install"
exit 0
EOF
chmod +x "$HOME/.hermes/hermes-agent/venv/bin/hermes"
printf "model: anthropic/claude-sonnet-4\n" > "$HOME/.hermes/config.yaml"

printf '\n\n' | HOME="$HOME" "$HOME/.agent/extensions/ankh/bin/ankh" uninstall
[[ ! -e "$HOME/.agent/extensions/ankh/runtime" ]] || { echo "[✗] uninstall did not remove Ankh runtime" >&2; exit 1; }
[[ -x "$HOME/.agent/extensions/ankh/bin/hermes" ]] || { echo "[✗] uninstall did not restore hermes wrapper" >&2; exit 1; }
HOME="$HOME" "$HOME/.agent/extensions/ankh/bin/hermes" --help >/dev/null 2>&1 || { echo "[✗] hermes wrapper did not fall back to default Hermes after uninstall" >&2; exit 1; }

(cd "$PACKAGE_ROOT" && HOME="$HOME" CACHE_DIR="$CACHE_DIR" BUILD_DIR="$BUILD_DIR" RESOLVED_FILE="$RESOLVED_FILE" bash src/scripts/build/install.sh)
(cd "$PACKAGE_ROOT" && HOME="$HOME" CACHE_DIR="$CACHE_DIR" BUILD_DIR="$BUILD_DIR" RESOLVED_FILE="$RESOLVED_FILE" bash src/scripts/build/build.sh)
(cd "$PACKAGE_ROOT" && HOME="$HOME" CACHE_DIR="$CACHE_DIR" BUILD_DIR="$BUILD_DIR" RESOLVED_FILE="$RESOLVED_FILE" bash src/scripts/build/deploy.sh)
[[ -x "$HOME/.agent/extensions/ankh/bin/ankh" ]] || { echo "[✗] install/build/deploy did not restore ankh wrapper" >&2; exit 1; }
[[ ! -e "$HOME/.agent/extensions/ankh/runtime/hermes" ]] || { echo "[✗] redeploy should not recreate runtime/hermes" >&2; exit 1; }
[[ ! -e "$HOME/.agent/extensions/ankh/runtime/bin" ]] || { echo "[✗] redeploy should not recreate runtime/bin" >&2; exit 1; }
HOME="$HOME" BUILD_DIR="$BUILD_DIR" TARBALL_PATH="$tarball_path" bash "$PACKAGE_ROOT/src/scripts/test/assertions.sh"

echo "[✓] Tarball E2E passed"
