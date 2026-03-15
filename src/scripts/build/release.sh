#!/bin/bash
# Create releases/ankh.tgz from a clean package copy (excludes local runtime/cache artifacts).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="${PKG_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
RELEASES_DIR="$PKG_ROOT/releases"
RELEASE_TGZ="$RELEASES_DIR/ankh.tgz"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PKG_COPY="$TMP_DIR/pkg-copy"
cp -a "$PKG_ROOT" "$PKG_COPY"

# Exclude artifacts that must not ship (same as e2e-tarball)
find "$PKG_COPY/examples" -type f \( -name "state.db" -o -name "state.db-shm" -o -name "state.db-wal" \) -delete 2>/dev/null || true
find "$PKG_COPY/examples" -type d -name ".hub" -path "*/.agent/skills/*" -exec rm -rf {} + 2>/dev/null || true
find "$PKG_COPY/examples" -type f -name ".bundled_manifest" -path "*/.agent/skills/*" -delete 2>/dev/null || true
find "$PKG_COPY/examples" -type f \( -name "auth.json" -o -name "processes.json" -o -name "modal_snapshots.json" -o -name "singularity_snapshots.json" \) -path "*/.agent/*" -delete 2>/dev/null || true
find "$PKG_COPY" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$PKG_COPY" -type f \( -name ".DS_Store" -o -name "*.pyc" \) -delete 2>/dev/null || true

mkdir -p "$RELEASES_DIR"
tarball_name="$(cd "$PKG_COPY" && npm pack --silent)"
mv "$PKG_COPY/$tarball_name" "$RELEASE_TGZ"
echo "[✓] Release: $RELEASE_TGZ"
