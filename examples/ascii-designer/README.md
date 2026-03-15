# ASCII Designer

An agent that creates text art, banners, and fun terminal-style visuals.

## What It Does

- **Text banners** – Turns words into fancy ASCII art (e.g. big block letters)
- **Decorative boxes** – Puts borders and frames around text
- **Cowsay-style output** – Classic terminal-style speech bubbles and characters
- **Multiple styles** – Different fonts and layouts for different looks

## How It Works

The agent uses tools like pyfiglet, cowsay, and boxes, plus a free online API. No API keys are needed for basic use—just ask it to make something and it will generate the commands or output for you.

## Try It

From the ankh repo root:

```bash
cd examples/ascii-designer
hermes
```

Ask for things like "make a banner that says Hello World" or "draw a box around this text."
