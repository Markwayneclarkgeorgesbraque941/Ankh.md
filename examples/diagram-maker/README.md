# Diagram Maker

An agent that creates diagrams and flowcharts you can open in Excalidraw.

## What It Does

- **Architecture diagrams** – Shows how systems or components connect
- **Flowcharts** – Visualizes steps, decisions, and processes
- **Concept maps** – Links ideas and relationships
- **ASCII-style diagrams** – Simple text-based diagrams for quick sketches

## How It Works

The agent writes Excalidraw files (`.excalidraw`), which you can open at [excalidraw.com](https://excalidraw.com) or in any Excalidraw-compatible app. It can also create ASCII-style diagrams when you want something simpler.

## Try It

From the ankh repo root:

```bash
cd examples/diagram-maker
hermes
```

Describe what you want to visualize (e.g. "a flowchart for user login") and it will generate the diagram file for you.
