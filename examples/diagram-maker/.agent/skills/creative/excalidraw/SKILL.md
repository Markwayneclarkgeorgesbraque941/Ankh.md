---
name: excalidraw
description: Create hand-drawn style diagrams using Excalidraw JSON format. Generate .excalidraw files for architecture diagrams, flowcharts, and concept maps.
metadata:
  hermes:
    tags: [Excalidraw, Diagrams, Flowcharts, Architecture, JSON]
---

# Excalidraw Diagram Skill

Create diagrams by writing Excalidraw element JSON and saving as `.excalidraw` files. Open at [excalidraw.com](https://excalidraw.com).

## Format

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "hermes-agent",
  "elements": [ ... ],
  "appState": { "viewBackgroundColor": "#ffffff" }
}
```

## Element types

- `rectangle`, `ellipse`, `diamond` – shapes
- `arrow` – connections
- `text` – labels (use containerId to bind to shapes)

Save to any path, e.g. `diagram.excalidraw`.
