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
python3 -m pyfiglet --list_fonts
```

## Asciified API (no install)

```bash
curl -s "https://asciified.thelicato.io/api/v2/ascii?text=Hello+World"
curl -s "https://asciified.thelicato.io/api/v2/ascii?text=Hello&font=Doom"
```

## Cowsay

```bash
cowsay "Hello World"
cowsay -f tux "Linux rules"
cowthink "Hmm..."
```

## Boxes (borders)

```bash
echo "Hello" | boxes -d stone
echo "Hello" | boxes -d cat
```
