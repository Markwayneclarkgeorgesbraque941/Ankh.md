# Agent Ankh

For full package documentation, see `README.md` in the repository root.

Ankh extends [Hermes Agent](https://hermes-agent.nousresearch.com/) with per-folder scoping. Each project can have its own config, tools, skills, and session history.

## How it works

When you run `hermes` in a directory that contains a valid `.agent/config.yaml`, Hermes uses project-local settings:

- **config.yaml** – model, toolsets, terminal settings (merged with `~/.hermes`)
- **.env** – API keys (project-specific, inherits from `~/.hermes`)
- **auth** – read global + local; write to `.agent/auth.json` when in scope
- **agent.jsonc** – optional metadata (mainframe, uuid, title for banner identity; mainframe must be "hermes")
- **skills/** – project-local skills (authoritative; bundled sync skipped in scope)
- **memories/** – project-local MEMORY.md, USER.md
- **state.db** – project-local session history at `.agent/storage/state.db`
- **cron/** – jobs, output, lock
- **gateway** – gateway.json, sessions, hooks, pairing, caches
- **process registry, TTS, environment snapshots** – scoped to `.agent/`

Outside a valid project `.agent/` scope, Hermes uses global `~/.hermes/` as usual. Set `HERMES_ANKH_SCOPE=global` to force global-only.

## Commands

| Command | Description |
|---------|-------------|
| `hermes ankh` | Passthrough to ankh (setup, uninstall, etc.) |
| `hermes` | Run Hermes (uses .agent/ when present) |
| `ankh setup` | Check the installed Ankh runtime, PATH readiness, and Hermes global setup |
| `ankh uninstall` | Remove Ankh runtime/wrappers and optionally Hermes/data |

## Quick start

1. **Install** (if needed): `bun bootstrap` from the package root to repair
2. **Setup** (if needed): `ankh setup` then complete Hermes global setup in `~/.hermes`
3. **Configure a project**: Create `.agent/config.yaml` in your project
4. **Run**: `hermes` from that directory

Ankh runtime assets live in `~/.agent/extensions/ankh/runtime`. Hermes' native global config, auth, and session data continue to live in `~/.hermes`.

## Example .agent layout

```
my-project/
├── .agent/
│   ├── config.yaml   # model, toolsets, etc.
│   ├── .env          # API keys (optional, inherits from ~/.hermes)
│   ├── agent.jsonc   # optional: agent metadata (mainframe, uuid, title)
│   ├── skills/       # project-local skills
│   └── storage/
│       └── state.db  # session history
└── src/
```

## Scope behavior

- **Valid scope**: Directory (or ancestor) contains `.agent/config.yaml`
- **Global override**: Set `HERMES_ANKH_SCOPE=global` to use only `~/.hermes` (no project merge)
- **Fallback**: Outside valid scope, `hermes` runs the default Hermes install (if present)
- **Integrity guard**: `ankh setup` and scoped `hermes` block when the installed runtime is missing or no longer Ankh-patched and tell you to run `bun bootstrap`. `hermes ankh` passthroughs to ankh.
- **Uninstall**: `ankh uninstall` never touches project-local `.agent/` folders

## Known behavior

- **hermes --worktree / -w**: `.agent/` is typically gitignored, so worktrees won't inherit `.agent` config unless you track `.agent/config.yaml` in git.
- **hermes doctor**: May report global paths only when run in scope.
- **hermes setup**: Inside an `.agent` project, setup writes to `.agent/` (scoped), not `~/.hermes`. For global setup, run `hermes setup` from outside a project or with `HERMES_ANKH_SCOPE=global`.

## Docs

- [Hermes Agent](https://hermes-agent.nousresearch.com/)
- [Hermes GitHub](https://github.com/NousResearch/hermes-agent)
