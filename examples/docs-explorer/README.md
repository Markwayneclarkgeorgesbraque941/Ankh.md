# Docs Explorer

A documentation site that explains how Agent Ankh works and where to find things in the project.

## What It Does

- **Explains the basics** – Workflow, commands, and how Ankh differs from Hermes
- **Maps the project** – Shows where important files live (binaries, scripts, config, examples)
- **Doubles as an agent** – You can also chat with an agent tuned to answer questions about this repo

## How It Works

This folder is a Mintlify docs site (HTML pages built from the `.mdx` files) plus an Agent Ankh project. You can browse the docs in a browser or chat with the agent to ask about the codebase.

## Preview the Docs

From this folder:

```bash
mintlify dev
```

Or use the Mintlify VS Code extension to preview locally.

## Chat with the Docs Agent

From the ankh repo root:

```bash
cd examples/docs-explorer
hermes
```

The agent is set up to help with questions about Agent Ankh and how to navigate the repo.
