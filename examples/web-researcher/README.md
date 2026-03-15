# Web Researcher

An agent that searches the web, visits pages, and helps you research and summarize topics.

## What It Does

- **Searches the web** – Finds articles, docs, and pages about whatever you ask
- **Reads and summarizes** – Pulls out the important parts so you don't have to read everything
- **Remembers context** – Keeps track of what you've discussed so it can build on earlier answers
- **Uses the browser** – Can open real web pages when needed

## How It Works

The agent has skills for search (including DuckDuckGo and arXiv), digesting sources, and working with documents. It can also delegate tasks to stay focused on your research.

## Try It

From the ankh repo root:

```bash
cd examples/web-researcher
hermes
```

**Note:** For full web search and browser features, add your API keys to `.agent/.env`. You can copy from `src/resources/defaults/.env.example` to get started.
