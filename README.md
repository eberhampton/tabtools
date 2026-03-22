# TabTools.dev

Fast, clean developer utilities — the tabs you keep open while you work.

## What This Is

TabTools is a collection of free browser-based tools for developers, IT professionals, and anyone who works with data. Each tool does one thing well, loads fast, and stays out of your way. No sign-ups, no bloat, no pop-ups.

## Planned Tools

- **JSON Formatter** — Paste messy JSON, get it pretty-printed, validated, and syntax-highlighted
- **Cron Expression Builder** — Visual cron schedule builder with plain-English translation and next-run preview
- **Webhook Tester** — Unique URL that logs incoming requests in real time for debugging integrations
- **Placeholder Image Generator** — Custom placeholder images by size, color, and text
- **Markdown Resume Builder** — Write your resume in Markdown, preview live, export as PDF
- **Text Utilities** — Word counter, case converter, character counter, text diff
- **Random Generators** — Names, passwords, test data, writing prompts

Tools are released one at a time. This list will evolve.

## Tech Stack

- **Server:** Ubuntu 24.04 on DigitalOcean
- **Web server:** nginx with reverse proxy and SSL via Let's Encrypt
- **Frontend:** Vanilla HTML, CSS, and JavaScript (no framework — speed is the priority)
- **Backend:** Node.js + Express (only for tools that need server-side processing)
- **Domain:** tabtools.dev

## Development Workflow

This project follows a structured development process from day one:

- **Issues** track all planned work — features, bugs, infrastructure tasks
- **Branches** are created for each piece of work and merged into `main` when complete
- **Main** always reflects what's deployed to production
- **Commits** reference issue numbers and describe what changed and why
- **Documentation** is updated alongside code, not after the fact

## Project Structure

```
tabtools/
├── docs/               # Deployment guide, server setup notes
├── site/               # Site shell — homepage, shared layout, styles
│   ├── index.html
│   ├── css/
│   └── shared/
├── tools/              # Each tool in its own directory
│   ├── json-formatter/
│   ├── cron-builder/
│   └── .../
└── server/             # Backend API (when needed)
```

## About

TabTools is built and maintained by [Eber (Tochina)](https://bobrew.dev). AI assists with code generation (primarily Claude). I handle infrastructure, deployment, design direction, and all operational decisions. This collaboration is disclosed openly — the same approach used across my other projects at [bobrew.dev](https://bobrew.dev).

## License

MIT

