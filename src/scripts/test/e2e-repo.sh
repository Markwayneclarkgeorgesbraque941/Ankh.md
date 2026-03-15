#!/bin/bash
# Run a clean repo-clone style validation in an isolated HOME/cache/build space.
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

echo "[*] Repo E2E temp root: $TMP_ROOT"
(cd "$PKG_ROOT" && HOME="$HOME" CACHE_DIR="$CACHE_DIR" BUILD_DIR="$BUILD_DIR" RESOLVED_FILE="$RESOLVED_FILE" bash src/scripts/build/install.sh)
(cd "$PKG_ROOT" && HOME="$HOME" CACHE_DIR="$CACHE_DIR" BUILD_DIR="$BUILD_DIR" RESOLVED_FILE="$RESOLVED_FILE" bash src/scripts/build/build.sh)
(cd "$PKG_ROOT" && HOME="$HOME" CACHE_DIR="$CACHE_DIR" BUILD_DIR="$BUILD_DIR" RESOLVED_FILE="$RESOLVED_FILE" bash src/scripts/build/deploy.sh)
[[ ! -e "$HOME/.agent/extensions/ankh/runtime/hermes" ]] || { echo "[✗] deploy should not create runtime/hermes" >&2; exit 1; }
[[ ! -e "$HOME/.agent/extensions/ankh/runtime/bin" ]] || { echo "[✗] deploy should not create runtime/bin" >&2; exit 1; }
(cd "$PKG_ROOT" && HOME="$HOME" CACHE_DIR="$CACHE_DIR" BUILD_DIR="$BUILD_DIR" RESOLVED_FILE="$RESOLVED_FILE" bash src/scripts/test/assertions.sh)

mkdir -p "$HOME/.hermes/hermes-agent/venv/bin"
cat > "$HOME/.hermes/hermes-agent/venv/bin/hermes" <<'EOF'
#!/bin/bash
echo "default hermes install"
exit 0
EOF
chmod +x "$HOME/.hermes/hermes-agent/venv/bin/hermes"
printf "model: anthropic/claude-sonnet-4\n" > "$HOME/.hermes/config.yaml"

HOME="$HOME" KEEP_HERMES=yes KEEP_ANKH_DATA=yes KEEP_HERMES_DATA=yes "$HOME/.agent/extensions/ankh/bin/ankh" uninstall
[[ ! -e "$HOME/.agent/extensions/ankh/runtime" ]] || { echo "[✗] uninstall did not remove Ankh runtime" >&2; exit 1; }
[[ -x "$HOME/.agent/extensions/ankh/bin/hermes" ]] || { echo "[✗] uninstall did not restore hermes wrapper" >&2; exit 1; }
HOME="$HOME" "$HOME/.agent/extensions/ankh/bin/hermes" --help >/dev/null 2>&1 || { echo "[✗] hermes wrapper did not fall back to default Hermes after uninstall" >&2; exit 1; }

(cd "$PKG_ROOT" && HOME="$HOME" CACHE_DIR="$CACHE_DIR" BUILD_DIR="$BUILD_DIR" RESOLVED_FILE="$RESOLVED_FILE" bash src/scripts/build/install.sh)
(cd "$PKG_ROOT" && HOME="$HOME" CACHE_DIR="$CACHE_DIR" BUILD_DIR="$BUILD_DIR" RESOLVED_FILE="$RESOLVED_FILE" bash src/scripts/build/build.sh)
(cd "$PKG_ROOT" && HOME="$HOME" CACHE_DIR="$CACHE_DIR" BUILD_DIR="$BUILD_DIR" RESOLVED_FILE="$RESOLVED_FILE" bash src/scripts/build/deploy.sh)
[[ -x "$HOME/.agent/extensions/ankh/bin/ankh" ]] || { echo "[✗] install/build/deploy did not restore ankh wrapper" >&2; exit 1; }
[[ ! -e "$HOME/.agent/extensions/ankh/runtime/hermes" ]] || { echo "[✗] redeploy should not recreate runtime/hermes" >&2; exit 1; }
[[ ! -e "$HOME/.agent/extensions/ankh/runtime/bin" ]] || { echo "[✗] redeploy should not recreate runtime/bin" >&2; exit 1; }
(cd "$PKG_ROOT" && HOME="$HOME" CACHE_DIR="$CACHE_DIR" BUILD_DIR="$BUILD_DIR" RESOLVED_FILE="$RESOLVED_FILE" bash src/scripts/test/assertions.sh)

echo "[✓] Repo E2E passed"
