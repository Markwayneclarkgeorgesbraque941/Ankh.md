# Defaults

This directory mirrors the default `~/.hermes` layout used by Hermes Agent.
It is the baseline for example projects in `examples/`.

## Layout

- `config.yaml` – default model, toolsets, terminal, display, etc.
- `.env.example` – API keys and tool provider env vars
- `skills/` – default skills (example, global-baseline)

## Usage

Example projects use `.agent/config.yaml` for Hermes settings (model, toolsets, etc.).
Config merges with `~/.hermes/config.yaml` (local overrides global). Unknown keys
are preserved for forward compatibility with upstream Hermes docs.

Hermes uses real `~/.hermes` at runtime unless `HERMES_HOME` is set.
