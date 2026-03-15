# Plan Writer

An agent that turns your ideas and specs into clear, step-by-step implementation plans.

## What It Does

- **Breaks down tasks** – Takes a big goal and splits it into small, doable steps
- **Adds concrete details** – Suggests which files to edit, what code to write, and how to test
- **Keeps things bite-sized** – Each step is meant to take a few minutes, not hours
- **Documents everything** – Helps the implementer understand what to do without guessing

## How It Works

When you give it a spec or requirements, the agent uses the writing-plans skill to create a structured plan with prerequisites, tasks, verification steps, and even rollback notes if something goes wrong.

## Try It

From the ankh repo root:

```bash
cd examples/plan-writer
hermes
```

Tell it what you want to build or implement, and it will produce a plan you can follow.
