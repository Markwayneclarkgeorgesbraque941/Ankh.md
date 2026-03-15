#!/bin/bash
[[ -z "${PKG_ROOT:-}" ]] && { echo "PKG_ROOT required. Source this script after setting PKG_ROOT." >&2; exit 1; }
# Load vendor.json as source of truth. Requires PKG_ROOT.
# Sets: VENDOR_VERSION, VENDOR_SOURCE_URL, VENDOR_SOURCE_BRANCH,
#       VENDOR_CACHE_DIR, VENDOR_BUILD_DIR, VENDOR_PATCHES_DIR, VENDOR_SCRIPTS_DIR

VENDOR_JSON="${VENDOR_JSON:-$PKG_ROOT/src/vendor.json}"
if [[ ! -f "$VENDOR_JSON" ]]; then
    echo "vendor.json not found: $VENDOR_JSON" >&2
    exit 1
fi

_vendor_arr=()
while IFS= read -r line; do _vendor_arr+=("$line"); done < <(python3 - "$VENDOR_JSON" "$PKG_ROOT" <<'PY'
import json
import sys
from pathlib import Path
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
pkg = Path(sys.argv[2])
src = data.get("source", {})
paths = data.get("paths", {})
version = src.get("version", "main")
cache_tpl = paths.get("cache", "./.build/cache/{version}")
cache = cache_tpl.replace("{version}", version)
build = paths.get("build", "./.build")
patches = paths.get("patches", "./src/patches")
scripts = paths.get("scripts", "./src/scripts")
for p in [(pkg / cache).resolve(), (pkg / build).resolve(), (pkg / patches).resolve(), (pkg / scripts).resolve()]:
    print(str(p))
print(version)
print(src.get("url", ""))
print(src.get("branch", version))
PY
)

VENDOR_CACHE_DIR="${_vendor_arr[0]}"
VENDOR_BUILD_DIR="${_vendor_arr[1]}"
VENDOR_PATCHES_DIR="${_vendor_arr[2]}"
VENDOR_SCRIPTS_DIR="${_vendor_arr[3]}"
VENDOR_VERSION="${_vendor_arr[4]}"
VENDOR_SOURCE_URL="${_vendor_arr[5]}"
VENDOR_SOURCE_BRANCH="${_vendor_arr[6]}"
