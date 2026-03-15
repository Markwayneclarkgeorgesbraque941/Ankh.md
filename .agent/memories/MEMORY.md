# About Ankh.md

Ankh.md is an AI agent framework with modular architecture for building intelligent assistants. Focus: flexible, extensible framework for custom agents.

Key Features:
- Modular agent architecture
- Support for various AI models/backends
- Extensible skill system
- Memory & context management
- Console-based interface

Main Components:
1. Hermes Agent - core agent runtime
2. Agent Ankh - framework orchestrating agent behavior
3. Skills System - reusable procedures/knowledge bases
4. Memory System - persistent storage for preferences & learned info

Project Structure:
- /src/ - source code
- /examples/ - example agent configs & profiles

Use Cases: documentation exploration, web research, creative tasks, planning/organization, technical assistance.

# Agent Ankh – Learned Memory

## Learned User Preferences

- Example folders are named by what they represent (e.g. web-researcher, docs-explorer), not project-* placeholders.
- Keep example content self-contained under examples/ (e.g. docs-explorer lives under examples/).
- Defaults live in src/resources/defaults; examples inherit from there via .agent/agent.jsonc.
- Standardize example session DB path at .agent/storage/state.db.
- Strip nested .git from cloned vendor sources so only the package root has .git.
- Prefer only ankh and hermes binaries; avoid ankh-hermes.
- hermes should use the modded Ankh runtime only inside a valid .agent project; otherwise use default Hermes.
- Ankh banner changes should preserve native Hermes visual fidelity when compacted, with concise scoped agent info instead of distorted/stylized logo rewrites.
- Install, build, deploy, and test must work end-to-end.
- Mintlify theme must be venus, quill, or prism; favicon is required.
- Edit source code (patches, scripts, patch/banner.py), not cache files; cache is generated during install.

## Learned Workspace Facts

- ankh is a standalone package at /Users/computer/Repositories/Agent/agent-ankh.
- Examples inherit from src/resources/defaults (config, env_example, skills_root).
- Example profiles: docs-explorer, web-researcher, ascii-designer, diagram-maker, plan-writer.
- Each example profile uses .agent/config.yaml, .agent/agent.jsonc, and local .agent/skills/.
- Version and paths: src/vendor.json (source of truth).
- Vendor manifest is located at src/vendor.json.
- Runtime help doc is located at src/resources/console/help.md.
- Example session DB target path is .agent/storage/state.db.
- .agent/agent.jsonc supports mainframe (hermes only), uuid, and title metadata; banner title defaults to "A Wandering Agent" when title is missing.
- In Ankh scope, .agent/skills/ is authoritative; bundled skill sync is skipped so user-deleted skills are not recreated.
- Scope detection uses .agent/config.yaml at root of .agent/; .agent/config/hermes.yaml is not used for scope.
