#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Agent Ankh Test Orchestrator
# ═══════════════════════════════════════════════════════════════════════════
# Single entry point for all tests. Runs e2e-repo and e2e-tarball.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="${PKG_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

bash "$PKG_ROOT/src/scripts/test/e2e-repo.sh" && bash "$PKG_ROOT/src/scripts/test/e2e-tarball.sh"
