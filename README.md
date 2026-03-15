# Ankh.md

**[Ankh.md](https://Ankh.md)** (also known as Agent Ankh) is a 100% free, open-source, MIT-licensed agentic framework that helps you go from one Hermes Agent to multiple individually scoped Hermes Agents. 

Ankh Hermes Agents live within your files & projects to help you create & use specialized agentic workflows.

By default, Hermes Agent is a default experience you call from anywhere using `hermes`. After you install Ankh.md & craft a local agent in a folder, the `hermes` command runs the Ankh instead of the default Hermes Agent.

When running a scoped Ankh Hermes Agent, the agent acts as an independent instance of Hermes Agent. You can configure this instance with a custom model, skills, tools, instructions, and other Hermes-supported features.

## Key Features

- **Per-folder scoping** – Each project gets its own agent; config, skills, sessions, and memories live in `.agent/`
- **Config merge** – Global `~/.hermes` baseline + local `.agent/config.yaml` overrides per project
- **Project-local skills** – `.agent/skills/` per project; each agent can have a different skill set
- **Seamless switching** – Run `hermes` in an Ankh folder → scoped agent; outside → default Hermes
- **Agent identity** – `.agent/agent.jsonc` for custom title, prompt, and instructions per project

See [DOCS.md](DOCS.md) for a full feature breakdown & general guidance.

## Getting Started

### Prerequisites

- **macOS** (other platforms supported by Hermes Agent such as Linux might work; however, we only tested macOS)
- **Terminal** (a console where you run your commands)
- **Bun** (to run the installer)
- **Git** (to clone upstream dependencies)
- **Hermes Agent** (installed & configured on your computer)
- **Python 3.11+** for the Hermes runtime & other features

If you already have Hermes Agent, you'll most likely only need to install `bun` before you can start with your Ankh.md setup.

### Setup

It only takes a few minutes to get started with Ankh.md. 
1. Download this repository to your computer
2. Unzip and navigate to its path in your Terminal (e.g. `cd ~/Downloads/Ankh.md-divine`).
3. Run `bun bootstrap`. This downloads Hermes Agent, patches it, and deploys Ankh to `~/.agent/extensions/ankh`. 
4. Your Ankh.md PATH should be automatically configured by the installer. 
  -  If you need to add it manually, run `export PATH="$HOME/.agent/extensions/ankh/bin:$PATH"` in your Terminal.
5. Run `hermes` in the project folder, or in any of the project `examples/` to see Ankh Hermes Agents in action.

That's it! You can now use the examples to craft your own Ankh Hermes Agents anywhere on your computer and chat with them using the `hermes` command when run in their folder.

## How it Works

You still have access to your default Hermes Agent, untouched by Ankh.md whenever you run `hermes` in a non-Ankh directory.

However, if a valid Ankh `.agent` exists where you run your `hermes` command, the Ankh dynamically recognizes that and runs a custom version of Hermes Agent scoped to your folder.

This custom version ensures your AI Agent is specialized in whatever’s relevant to your project, repo, or general folder. 

### Quick Notes

- Always check the `examples/` for ideas and references on how to set up your Ankh Hermes Agents.
- Ankh.md stores all its global runtime files under the `~/.agent/extensions/ankh` folder.
- Ankh Hermes Agents store their data in the folder where they’re set up, under a `.agent` subfolder.
- They support `skills` you can set up under the `.agent/skills` folder, `tools` (via the `.agent/config.yaml` file), custom instructions (via the `.agent/agent.jsonc` file), and more.
- Not all Hermes Agent features are currently supported. If you face any issues, please submit a PR with a tested fix or post an issue if you were unable to sort it out.
- Gateway, cron, and scoped auth are still work in progress, untested, and unlikely to be supported. So features like Telegram, WhatsApp, or external apps are yet to be enabled.
- We plan to roll out a wrapper gateway that orchestrates multiple individual Hermes Agent gateways in a network-efficient protocol, or to work with Nous Research to add support for scoped agent UUIDs.

### Safety & Security

Your default Hermes Agent stays untouched. The Ankh runs its own modded version of Hermes Agent when a valid `.agent` exists, however it doesn’t edit your original Hermes Agent.

Your Ankh Hermes Agents are fully configurable and customizable and the base assumption here is that you’re following all the best practices documented in the Nous Research docs.

Ankh.md does not claim responsibility for any lost data. Use Git repos to commit your `.agent` folder. Inside of that folder, you can also choose to ignore `memories` from storage if you want to keep those private & not commit them to the repo for the rest of your team.

### Use Cases

- **Per-codebase coding agent** – One agent per repo with project-local skills, memories, and context; no cross-pollution between projects
- **Documentation you can chat with** – Docs-explorer style: navigate codebase, answer questions about structure and where things live
- **Web research & synthesis** – Search, visit pages, extract content, and summarize; DuckDuckGo, arXiv, domain intel, document extraction
- **Diagrams & flowcharts** – Generate Excalidraw files for architecture, flows, and concept maps
- **Implementation plans** – Turn specs into step-by-step plans with tasks, verification steps, and rollback notes
- **Creative & terminal art** – ASCII banners, pyfiglet, cowsay, boxes for text art and terminal visuals
- **Sub-agent delegation** – Main agent spawns focused sub-agents with different toolsets (e.g. research sub-agent for synthesis)
- **Team-shared agents** – Commit `.agent/` to share config, skills, and memories; ignore `memories/` if you want them private

## Examples

### Built-in Examples

Inside the `examples/` folder, as well as in the project root, you can find Ankh Hermes Agents you can use as inspiration.

You can call `hermes` in the repo root, which has its own Ankh Hermes Agent, or inside any of the example folders.

| Profile | Description |
|---------|-------------|
| **docs-explorer** | Documentation site and agent for navigating the Agent Ankh codebase. Mintlify docs + chat agent. |
| **web-researcher** | Web search, page visits, and research summarization. Skills for DuckDuckGo, arXiv, domain intel, and document extraction. |
| **ascii-designer** | Text art, banners, and terminal-style visuals using pyfiglet, cowsay, and boxes. |
| **diagram-maker** | Excalidraw diagrams and flowcharts. Creates `.excalidraw` files for architecture, flowcharts, and concept maps. |
| **plan-writer** | Turns specs and ideas into step-by-step implementation plans with tasks, verification steps, and rollback notes. |

### Hypothetical Example

- **Default Hermes Agent**
  - “What did we work on yesterday in this project?”
  - “Which project? Where can I find it? I see we worked on multiple.”
- **Ankh Hermes Agent**
  - “What did we work on yesterday in this project?”
  - “Hey, Agent Repo dev here! Yesterday we rolled out 3 commits on Agent and you said you wanted to leave the other stuff in the project team Linear for today. Ready to pick up the responsive fixes together or would you like to focus on something else?”

## Commands

### Ankh Commands

| Command | Description |
|---------|--------------|
| `ankh` | Run the default Ankh.md command (currently shows `ankh --help`) |
| `ankh setup` | Check the installed Ankh runtime, PATH readiness, and Hermes global setup |
| `ankh uninstall` | Remove Ankh runtime/wrappers and optionally Hermes/data |

**Note:** Add `~/.agent/extensions/ankh/bin` to your PATH for these commands to work. See Setup above.

### Hermes Commands

| Command | Description |
|---------|--------------|
| `hermes` | Run patched Hermes only in valid `.agent/` projects; otherwise run default Hermes |
| `hermes ankh` | Passthrough to `ankh` (setup, uninstall, `--help`, etc.) |

## Troubleshooting

If you can't run the `ankh` command or if your `hermes` doesn't load your Ankh Hermes Agent:

1. If the command is missing entirely:

   Add `~/.agent/extensions/ankh/bin` to your PATH (required for commands to work):
   ```bash
   export PATH="$HOME/.agent/extensions/ankh/bin:$PATH"
   ```
   Add this to `~/.zshrc` or `~/.bashrc` for persistence. Or run this one-liner (macOS, idempotent):
   ```bash
   grep -qxF 'export PATH="$HOME/.agent/extensions/ankh/bin:$PATH"' ~/.zshrc 2>/dev/null || echo 'export PATH="$HOME/.agent/extensions/ankh/bin:$PATH"' >> ~/.zshrc
   ```

2. If `hermes` doesn't work at all, follow the Hermes Agent setup, configuration, or troubleshooting steps.

## Vision

Ankh.md exists to help you go from one default Hermes Agent, to an infinity of scoped Hermes Agents that live & grow with your projects locally. Currently a multi-agentic framework, Ankh.md aims to support your swarm orchestration end-to-end in upcoming releases.

The current focus is exclusive towards Nous Research’s Hermes Agent and ways to enhance it using optional Agent.so features.

While we’re not shutting the doors for future main frameworks outside of Hermes Agent in the future, we want to keep this project laser focused.

All feature requests & ideas are welcome, however please document your requests & suggestions accordingly in order for them to be considered. 

This project can only grow with your support.

## Contributions

We appreciate every contribution or PR you make to [Ankh.md](https://Ankh.md). If you’re not a developer, we also appreciate you sharing our launch video or posting creative content on social media to help people use Hermes Agent with Ankh.

Before submitting an issue or feature request to the repo Issues, ask your Ankh Hermes Agent to fix or build it locally first. With a working version, then please submit a PR. If that fails, feel free to submit an issue on the repo.

If this project gains enough interest, this simple process helps us stay organized and focus our resources efficiently.

## Funding & Sponsorships

This open-source library is 100% free and MIT-licensed. Meaning you can use it commercially, fork it, or do whatever you want according to the MIT licensing terms. We see this as both a gift to the agentic space, as well as a commitment to our broader long-term vision.

Ankh.md started as a solo project created by Alex Doda during the 2026 Nous Research Hermes Agent Hackathon. The project is published & maintained by Abruptive®, an independent group of creators & entrepreneurs who align their ventures towards the betterment of society.

If you wish to support us, help us stay bootstrapped and independent, please consider starting a paid membership on our flagship platform, Agent.so.

Agent.so is the original AI Agents platform, building towards becoming Your Portal to AI®. In the long-term, we're working with creators, developers, affiliates, and entrepreneurs to integrate & promote their products using the ecosystem we're building.

The platform helps you chat with dozens of AI models, including Nous Research models like Hermes, become an AI Expert to get paid for building, reselling, and deploying AI Agents to sites, and a lot more.

Should the Ankh.md project grow, we’re exploring avenues to two-way integrations with the Agent.so platform with your Hermes Agents. This will bring all the novel cloud-hosted capabilities we’re working on to your Ankh Hermes Agents.

In full transparency however, Hermes Agent isn’t currently supported on Agent.so. Additionally, Agent.so is not a coding-oriented platform.

Your support helps us allocate resources to Ankh.md, to The Agent World (TAW) project, towards building a better agentic infrastructure for Hermes Agent, as well as to motivate us to release even more open source tech & creative media around it in the future.

Here’s the link to learn more & see if it’s a fit.

[https://www.agent.so/](https://www.agent.so/)

## License

MIT