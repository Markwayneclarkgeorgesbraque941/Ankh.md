# Ankh.md Starter Docs

This document breaks down all the features that make Ankh.md work. If you're new here, start with the [README](README.md) for setup and quick start. A full docs site will be released soon. Meanwhile, here are some quick references to help you navigate Ankh.md.

Run the `ankh` command anytime to learn more about available features.

## Creating an Ankh Hermes Agent

Check out the `/examples` folder in the project repo for example `.agent` configurations. To set up a new agent in any other folder on your computer, simply create a `.agent` folder with a valid `agent.jsonc` and `config.yaml`. Then, run `hermes` inside that folder in your Terminal. 

If you did things right, you'll see the modded Hermes console (with the Ankh.md in the top-right header). Make sure you're on a wide enough window because the CLI doesn't mod the "mobile" breakpoint yet.

## Ankh vs Upstream Hermes


| Aspect           | Upstream Hermes                     | Agent Ankh                                                  |
| ---------------- | ----------------------------------- | ----------------------------------------------------------- |
| Config           | Global `~/.hermes/config.yaml` only | Global + project-local `.agent/config.yaml` (merged)        |
| Skills           | Global `~/.hermes/skills/`          | Project-local `.agent/skills/` when in scope                |
| Sessions         | Global `~/.hermes/state.db`         | Project-local `.agent/storage/state.db` when in scope       |
| `hermes` command | Single binary                       | Multiplexer: patched in `.agent` scope, else default Hermes |


## Per-Folder Scoping

Each project gets its own Ankh Hermes Agent. When you run `hermes` inside a folder that has a valid `.agent` directory, Ankh recognizes it and runs a custom Hermes Agent scoped to that folder.

Everything that makes your agent unique—config, skills, sessions, memories, and identity—lives under `.agent/` in that project. No cross-pollution between projects. Your docs-explorer agent doesn't see your web-researcher agent's history, and vice versa.

## Config Merge (Global + Local)

Your global Hermes config in `~/.hermes/config.yaml` provides the baseline. Each Ankh project can override it with `.agent/config.yaml`.

Ankh merges the two recursively. Local values override global ones. Unknown keys are preserved for forward compatibility with upstream Hermes.

You can customize per project:

- **model** – which LLM to use (e.g. `anthropic/claude-sonnet-4`, `qwen/qwen3.5-flash-02-23`)
- **toolsets** – which tools are enabled (web, file, browser, terminal, memory, skills, delegation, etc.)
- **memory** – `user_char_limit`, `memory_char_limit`
- **compression** – `threshold` for context summarization
- **delegation** – `max_iterations`, `default_toolsets` for sub-agent behavior
- **terminal**, **browser**, **display** – and any other Hermes config keys

## Project-Local Skills

Skills live in `.agent/skills/`. Each skill is a folder with a `SKILL.md` that describes when and how the agent uses it.

In Ankh scope, `.agent/skills/` is authoritative. Bundled skill sync is skipped, so skills you delete stay deleted. Add skills by creating a new folder under `.agent/skills/` with a `SKILL.md`. Remove them by deleting the folder.

Each Ankh Hermes Agent can have a completely different skill set. The docs-explorer agent has docs-navigation skills; the web-researcher has DuckDuckGo, arXiv, and domain intel; the diagram-maker has Excalidraw and ASCII art.

## Isolated Session History

Session data is stored per project at `.agent/storage/state.db`. Each agent keeps its own conversation history. When you switch projects and run `hermes`, you're talking to a different agent with a different history.

You can resume sessions with `-c` or `--resume`, list sessions, export them, or prune them—all scoped to the current project.

## Agent Identity (agent.jsonc)

Each Ankh Hermes Agent can have its own identity. The optional `.agent/agent.jsonc` file holds:

- **mainframe** – must be `"hermes"`
- **uuid** – unique identifier for the agent
- **title** – shown in the banner (e.g. "Ankh Assistant", "Web Researcher")
- **prompt** – custom instructions that shape how the agent behaves in this project

This lets you give each agent a name, a role, and project-specific instructions.

## Seamless Scope Switching

The same `hermes` command does different things depending on where you run it:

- **Inside a valid `.agent/` project** → runs the Ankh-patched Hermes runtime with project-local config, skills, sessions, and memories
- **Outside any Ankh project** → runs your default Hermes Agent, untouched

No separate binaries. No manual switching. Ankh detects the scope automatically.

Set `HERMES_ANKH_SCOPE=global` to force global-only mode and ignore any `.agent/` in the current directory.

Ankh-managed install assets live under `~/.agent/extensions/ankh/runtime`; binaries live under `~/.agent/extensions/ankh/bin`. Hermes global config, auth, and sessions stay in `~/.hermes`.

If the deployed runtime is replaced with an unpatched Hermes build, `ankh setup` and scoped `hermes` will stop and tell you to run `bun bootstrap` to repair.

`ankh uninstall` removes Ankh assets and wrappers but never touches project-local `.agent/` folders.

## Environment & Secrets (.env)

API keys and secrets are merged from `~/.hermes/.env` and `.agent/.env`. Project-specific keys in `.agent/.env` override global ones. Use this for per-project API keys (e.g. different Firecrawl keys for different agents).

## Project-Local Memories

Memories live in `.agent/memories/`. The agent learns and stores preferences, facts, and context per project. Your coding agent remembers your style; your research agent remembers your domains of interest—each in its own scope.

## Hermes Tools Preserved

Ankh does not remove or limit Hermes tools. You still get:

- **web** – search, extract
- **terminal** – run commands
- **file** – read, write, edit files
- **browser** – navigate and interact with pages
- **vision** – image understanding
- **image_gen** – generate images
- **tts** – text-to-speech
- **skills** – use installed skills
- **todo** – task tracking
- **memory** – persistent memory
- **session_search** – search past sessions
- **clarify** – ask for clarification
- **delegation** – spawn sub-agents
- **cron** – scheduled jobs
- **MCP** – Model Context Protocol tools

Configure which toolsets are enabled per project via `.agent/config.yaml`.

## Multi-Agentic Delegation

Ankh supports Hermes delegation. Your main agent can spawn sub-agents with different toolsets. For example, a web-researcher agent might delegate to a sub-agent with only `web` and `file` tools for focused research, then synthesize the results.

Configure delegation in `.agent/config.yaml`:

- **max_iterations** – how many delegation rounds
- **default_toolsets** – which tools the sub-agent gets

## Example Profiles

The `examples/` directory ships with ready-to-run Ankh Hermes Agents:


| Profile            | Use case                                                                      |
| ------------------ | ----------------------------------------------------------------------------- |
| **docs-explorer**  | Navigate docs and codebase; Mintlify docs + chat agent                        |
| **web-researcher** | Web search, page visits, DuckDuckGo, arXiv, domain intel, document extraction |
| **ascii-designer** | Text art, banners, pyfiglet, cowsay, boxes                                    |
| **diagram-maker**  | Excalidraw diagrams and flowcharts                                            |
| **plan-writer**    | Specs → step-by-step implementation plans with tasks, verification, rollback  |


Each has its own `.agent/config.yaml`, `.agent/agent.jsonc`, and `.agent/skills/`. Run `hermes` from inside any example folder to try it.

## What's Not Yet Supported

Gateway (Telegram, Discord, Slack, WhatsApp), cron, and scoped auth are work in progress, untested, and unlikely to be fully supported in the current release. We plan to roll out a wrapper gateway that orchestrates multiple Ankh Hermes Agent gateways, or to work with Nous Research on scoped agent UUIDs.

## Package Scripts (Build from Source)

From the repo root:


| Command          | Description                                                                                           |
| ---------------- | ----------------------------------------------------------------------------------------------------- |
| `bun install`    | Install package dependencies; runs install script (clone Hermes, apply patches)                       |
| `bun run build`  | Create venv and build Hermes in `.build/`                                                             |
| `bun run deploy` | Copy runtime to `~/.agent/extensions/ankh/runtime`, create wrappers in `~/.agent/extensions/ankh/bin` |
| `bun run test`   | Validate build, deploy, scoping, and uninstall flows                                                  |
| `bun bootstrap`  | Run install, build, and deploy                                                                        |


## Summary


| Feature              | Description                                                       |
| -------------------- | ----------------------------------------------------------------- |
| Per-folder scoping   | One agent per project; config, skills, sessions live in `.agent/` |
| Config merge         | Global `~/.hermes` + local `.agent/config.yaml` (local overrides) |
| Project-local skills | `.agent/skills/` authoritative; no bundled sync in scope          |
| Isolated sessions    | `.agent/storage/state.db` per project                             |
| Agent identity       | `.agent/agent.jsonc` for title, uuid, prompt                      |
| Scope switching      | `hermes` runs Ankh in `.agent` scope, default Hermes elsewhere    |
| .env merge           | API keys from `~/.hermes/.env` + `.agent/.env`                    |
| Memories             | `.agent/memories/` per project                                    |
| Hermes tools         | All tools preserved; enable per project via toolsets              |
| Delegation           | Sub-agents with configurable toolsets                             |


