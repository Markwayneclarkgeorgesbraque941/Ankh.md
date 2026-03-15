---
name: ascii-art
description: Generate ASCII art using pyfiglet, cowsay, boxes, and the asciified API. No API keys required.
metadata:
  hermes:
    tags: [ASCII, Art, Banners, Creative, pyfiglet, cowsay, boxes]
---

# ASCII Art Skill

## Text Banners (pyfiglet)

```bash
pip install pyfiglet
python3 -m pyfiglet "YOUR TEXT" -f slant
```

## Asciified API (no install)

```bash
curl -s "https://asciified.thelicato.io/api/v2/ascii?text=Hello+World"
```

## Cowsay / Boxes

```bash
cowsay "Hello"
echo "Hello" | boxes -d stone
```
