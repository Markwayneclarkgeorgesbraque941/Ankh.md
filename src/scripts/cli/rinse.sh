#!/bin/bash
# Remove known empty .agent subdirs (memories, sandboxes/singularity, sandboxes)
# that Hermes autocreates. Safe: rmdir only removes empty dirs.
set -euo pipefail

find_agent_dir() {
    local dir
    dir="$(cd "${1:-.}" && pwd)"
    local home_agent
    home_agent="$(cd "${HOME}/.agent" 2>/dev/null && pwd)" || true
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.agent" ]] && [[ -f "$dir/.agent/config.yaml" ]]; then
            if [[ -n "${home_agent:-}" ]] && [[ "$(cd "$dir/.agent" && pwd)" == "$home_agent" ]]; then
                dir="$(dirname "$dir")"
                continue
            fi
            echo "$dir/.agent"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

agent_dir="$(find_agent_dir 2>/dev/null)" || exit 0
[[ -z "$agent_dir" ]] && exit 0

# Remove only if empty (rmdir fails if non-empty)
rmdir "$agent_dir/memories" 2>/dev/null || true
rmdir "$agent_dir/sandboxes/singularity" 2>/dev/null || true
rmdir "$agent_dir/sandboxes" 2>/dev/null || true
