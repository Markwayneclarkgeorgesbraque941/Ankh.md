---
name: Ankh Development
description: Exact techniques, shortcuts, and references for AI agents developing ankh (Hermes with per-folder .agent/ scoping)
license: MIT
metadata:
  author: Abruptive LLC
  version: "1.0.0"
---

# Ankh Development Skill

Techniques and shortcuts for developing ankh. For global repo facts and preferences, see `AGENTS.md`.

## Quick Start

```bash
bun install
bun bootstrap
```

Add `~/.agent/extensions/ankh/bin` to PATH. Run `hermes ankh` or `ankh` for usage.

---

## Version Upgrade

### 1. Update pinned version

Edit `src/vendor.json` (source of truth):

```json
"source": {
  "type": "git",
  "url": "https://github.com/NousResearch/hermes-agent",
  "branch": "v2026.3.12",
  "version": "v2026.3.12"
}
```

- Set `version` and `branch` to the desired Hermes tag (e.g. `v2026.3.13`).

### 2. Fresh clone and reapply patches

Patches are applied against the cloned Hermes source. After a version bump, patches may fail:

```bash
# Force a clean cache for the new version
FRESH_CACHE=1 bash src/scripts/build/install.sh
```

If a patch fails, `install.sh` will exit with an error. Fix the patch in `src/patches/core/<name>.patch` and retry.

### 3. Patch resolution order

The apply order is defined in `src/scripts/build/install.sh` (the `for patch_name in ...` loop). Post-patch hooks: `directory` runs `identity.py`; `banner` runs `banner.py`.

### 4. Verify after upgrade

```bash
bun bootstrap
bun run test:e2e:repo
bun run test:e2e:tarball
```

---

## Build, Deploy, Test

| Command | Purpose |
|---------|---------|
| `bun run install` | Clone Hermes, apply patches → `.build/cache/<version>/` |
| `bun run build` | Create venv, bundle patched source → `.build/` |
| `bun run deploy` | Copy to `~/.agent/extensions/ankh/runtime`, create wrappers in `~/.agent/extensions/ankh/bin` |
| `bun run test` | Validate build, deploy, scoping, uninstall flows |
| `bun bootstrap` | install → build → deploy |
| `bun run reset` | Remove `.build` |

### Shortcuts

- **Full cycle**: `bun bootstrap`
- **Re-patch only** (no re-clone): `bun run install` (uses existing cache if hash matches)
- **Fresh patch run**: `FRESH_CACHE=1 bun run install`
- **Override paths** (for CI or isolation): `CACHE_DIR`, `BUILD_DIR`, `HOME`, `VERSION`

---

## Patch System

**Before working on patches**, read [src/patches/config.json](src/patches/config.json). It lists all patches with descriptions. Use it as the source of truth for what each patch does; do not hard-code patch names or descriptions in this skill.

### Layout

```
src/patches/
├── config.json          # Patch metadata (descriptions, enabled flags) – read this first
└── core/
    └── <name>.patch     # One file per patch; names match config.json core keys
```

Apply order is in `src/scripts/build/install.sh`. `terminal.patch` exists but is **not** in the install loop; it may be legacy or for future use.

### Creating or editing a patch

1. Read `src/patches/config.json` to understand existing patches.
2. Clone Hermes into `.build/cache/<version>/` (via `bun run install`).
3. Edit files under `.build/cache/<version>/` directly.
4. Generate a patch: `cd .build/cache/<version> && git diff > ../../../src/patches/core/<name>.patch`
5. Add `<name>` to the `for patch_name in ...` loop in `src/scripts/build/install.sh` if new.
6. Add an entry to `core` in `src/patches/config.json` (sorted alphabetically) with `enabled` and `description`.
7. Optionally add a post-patch hook in `run_patch_hook()` in `install.sh`.
8. Run `bun run install` to verify the patch applies.

### Patch hash caching

Install records a hash per patch in `.build/cache/<version>/.patches_applied_<name>`. If the patch file hash matches, it skips re-application. Use `FRESH_CACHE=1` to force a clean re-apply.

---

## Source and References

| Resource | Location |
|----------|----------|
| Hermes upstream | https://github.com/NousResearch/hermes-agent |
| Hermes docs | https://hermes-agent.nousresearch.com/docs/ |
| Hermes config reference | https://hermes-agent.nousresearch.com/docs/user-guide/configuration |
| Vendor manifest (version, paths, source) | `src/vendor.json` |
| Patched Hermes source | `.build/cache/<version>/` (after install) |
| Build output | `.build/` (venv + bundled source) |
| Deployed runtime | `~/.agent/extensions/ankh/runtime` |
| Runtime help (shipped with deploy) | `src/resources/console/help.md` |
| Defaults (mirrors ~/.hermes) | `src/resources/defaults/` (config.yaml, .env.example) |
| Patch metadata | `src/patches/config.json` |

---

## Scripts Reference

| Script | Role |
|--------|------|
| `src/scripts/build/install.sh` | Clone Hermes, apply patches (version from vendor.json) |
| `src/scripts/build/build.sh` | Venv, pip install, bundle source, create hermes entrypoint |
| `src/scripts/build/deploy.sh` | Copy to ~/.agent/extensions/ankh, write ankh/hermes/ankh-hermes wrappers |
| `src/scripts/test/test.sh` | Test orchestrator (runs e2e-repo, e2e-tarball) |
| `src/scripts/test/assertions.sh` | Build/deploy/scoping/uninstall/tarball assertions |
| `src/scripts/cli/cli.sh` | Shared CLI for install, setup, uninstall |
| `src/scripts/patch/identity.py` | Injects `get_agent_identity()` after directory.patch |
| `src/scripts/patch/banner.py` | Injects Ankh banner logic after banner.patch |
| `src/scripts/test/e2e-repo.sh` | Full install→build→deploy→test in isolated temp dir |
| `src/scripts/test/e2e-tarball.sh` | npm pack → install → ankh setup → test in isolated temp dir |

`bin/ankh` sets `AGENT_ANKH_PKG_ROOT` and execs `cli.sh`. Deployed wrapper at `~/.agent/extensions/ankh/bin/ankh` does the same with `VENDOR_DIR` from deploy time.

---

## Ensuring Everything Works

1. **Local**: `bun bootstrap` – must pass.
2. **Repo E2E**: `bun run test:e2e:repo` – clean clone flow in isolated HOME/cache/build.
3. **Tarball E2E**: `bun run test:e2e:tarball` – npm pack, global install, ankh setup, test.

Tarball tests enforce: only `ankh` in package.json bin; no hermes/ankh-hermes bins; no example state.db, .hub, auth.json, etc. in the tarball.

---

## Examples and Defaults

- **Examples**: `examples/docs-explorer`, `web-researcher`, `ascii-designer`, `diagram-maker`, `plan-writer` – each has `.agent/config.yaml`, `.agent/agent.jsonc`, local skills.
- **Defaults**: `src/resources/defaults/` – config, .env.example; examples inherit via `.agent/agent.jsonc` or convention.
- **Validation**: `cd examples/<profile> && hermes config` to verify scoped config.

---

## Conventions

- Prefer `ankh` and `hermes`; avoid `ankh-hermes` except as alias.
- Strip nested `.git` from cloned vendor; only package root keeps .git.
- Session DB path: `.agent/storage/state.db`.
- Mintlify themes: venus, quill, or prism; favicon required.
- Banner: preserve native Hermes visual fidelity; concise scoped agent info only.
