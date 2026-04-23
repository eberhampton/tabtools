# TabTools.dev

Fast, clean developer utilities — the tabs you keep open while you work.

## What This Is

TabTools is a collection of free browser-based tools for developers, IT professionals, and anyone who works with data. Each tool does one thing well, loads fast, and stays out of your way. No sign-ups, no bloat, no pop-ups.

## Live Tools

- **JSON Formatter** — Paste messy JSON, get it pretty-printed, validated, and syntax-highlighted
- **Cron Expression Builder** — Visual cron schedule builder with plain-English translation and next-run preview
- **Webhook Tester** — Unique URL that logs incoming requests in real time for debugging integrations
- **Placeholder Image Generator** — Custom placeholder images by size, color, and text
- **Text Utilities** — Word counter, case converter, character counter, find & replace, 17 transforms
- **Regex Tester** — Test regular expressions in real time with match highlighting and capture groups
- **Diff Checker** — Compare two blocks of text side by side with additions and deletions highlighted
- **Color Converter** — Convert between hex, RGB, and HSL with preview swatches and contrast checker

## Tech Stack

- **Server:** Ubuntu 24.04 on DigitalOcean
- **Web server:** nginx with reverse proxy and SSL via Let's Encrypt
- **Frontend:** Vanilla HTML, CSS, and JavaScript (no framework — speed is the priority)
- **Backend:** Node.js + Express (webhook tester only)
- **Process management:** systemd service for Node backend
- **Monitoring:** Custom healthcheck (22 tests), weekly/monthly email reports via Resend API
- **Backups:** Weekly cron backup of server configs, DigitalOcean snapshots
- **Analytics:** GoatCounter (privacy-respecting, no cookies)
- **SEO:** Google Search Console, sitemap.xml, Open Graph tags
- **Domain:** tabtools.dev

## Development Workflow

This project has been tracked with GitHub Issues from day one:

- **Issues** track all planned work — features, bugs, infrastructure tasks
- **Branches** are created for each piece of work and merged into `main` when complete
- **Main** always reflects what's deployed to production
- **Commits** reference issue numbers and describe what changed and why
- **Documentation** is updated alongside code, not after the fact

## Project Structure

```
tabtools/
├── docs/                  # Deployment guide, server config backups
│   ├── deployment.md
│   └── server-configs/
├── site/                  # All frontend files (nginx web root)
│   ├── index.html         # Homepage
│   ├── 404.html           # Custom error page
│   ├── sitemap.xml
│   ├── robots.txt
│   ├── css/
│   │   └── style.css      # Design system with dark/light mode
│   └── tools/
│       ├── json-formatter/
│       ├── cron-builder/
│       ├── webhook-tester/
│       ├── placeholder-images/
│       ├── text-utilities/
│       ├── regex-tester/
│       ├── diff-checker/
│       └── color-converter/
└── server/                # Node.js backend
    ├── webhook-server.js
    └── package.json
```

## About

TabTools is built and maintained by elhbridge. AI assists with code generation (primarily Claude). I handle infrastructure, deployment, design direction, and all operational decisions.

## License

MIT
