# my-pi-setup

Portable configuration for the [pi coding agent](https://pi.dev) — clone this repo on any
Windows or Linux/macOS machine and run one script to reproduce my entire pi setup:
provider defaults, theme, custom skills, prompts, agents, and all installed packages
(web access, subagents, LSP/lint, MCP, memory, background tasks, fuzzy search, browser debugging).

---

## 🚀 Quick start

### Windows (PowerShell)
```powershell
git clone https://github.com/shankar029/my-pi-setup.git
cd my-pi-setup
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

### Linux / macOS (bash)
```bash
git clone https://github.com/shankar029/my-pi-setup.git
cd my-pi-setup
chmod +x setup.sh
./setup.sh
```

Then, on the new machine, authenticate once (secrets are **never** stored in this repo):
```
pi
/login        # log in to your provider (default: github-copilot)
```

That's it.

---

## 📦 What gets installed

The setup script:
1. Installs pi globally: `npm install -g --ignore-scripts @earendil-works/pi-coding-agent@latest`
2. Copies the portable config from [`agent/`](agent/) into `~/.pi/agent/`
3. Runs `pi update --all`, which reads `settings.json` and installs every listed package
4. Installs the Playwright **Chromium** binary (needed by `pi-browser-debug`)

### Packages (from `agent/settings.json`)
| Package | Purpose |
|---|---|
| `pi-web-access` | Web search, URL/PDF/repo/video fetching |
| `@tintinweb/pi-subagents` | Subagent delegation & workflow orchestration |
| `pi-lens` | Real-time LSP, linters, formatters, type-checking |
| `pi-mcp-adapter` | Connect any MCP (Model Context Protocol) server |
| `pi-memory` | Persistent semantic memory across sessions |
| `pi-background-tasks` | Durable background shell tasks & delegated agents |
| `@ff-labs/pi-fff` | Fast fuzzy file & content search |
| `@juicesharp/rpiv-todo` | Live persistent todo overlay |
| `pi-browser-debug` | Playwright browser automation — test/debug apps, console, network, JS |

### Custom resources
- **Skill:** `bulletproof` — end-to-end production-quality delivery workflow (`/bulletproof <requirement>`)
- **Prompts & agents:** the `bulletproof` prompt templates and helper agents

---

## 🗂️ Repo layout

```
my-pi-setup/
├── README.md
├── .gitignore              # keeps secrets & caches out of git
├── setup.ps1               # Windows installer
├── setup.sh                # Linux / macOS installer
└── agent/                  # portable config → copied to ~/.pi/agent/
    ├── settings.json       # provider, model, theme, package list
    ├── skills/bulletproof/ # custom skill
    ├── prompts/            # prompt templates
    └── agents/             # custom agents
```

---

## 🔒 Security — what is NOT in this repo

The following are **git-ignored** and must be regenerated / re-entered per machine:

| Excluded | Why | How it's restored |
|---|---|---|
| `auth.json` | 🔴 Live OAuth tokens / API keys | Run `/login` after setup |
| `npm/`, `git/` | Installed package code | `pi update --all` reinstalls from `settings.json` |
| `bin/` | Downloaded binaries (ripgrep, fd) | pi downloads on demand |
| `fff/`, `memory/`, `web-search-cache/` | Local caches | Rebuilt automatically |
| `sessions/`, `run-history.jsonl`, `models-store.json` | Machine-local history | `pi update --models` rebuilds the catalog |

> ⚠️ **Never commit `auth.json`.** If tokens ever land in git history, rotate them immediately.

---

## 🔄 Updating this setup

After changing packages/skills/settings on your main machine, sync them back into the repo:

```bash
# from the repo root
cp ~/.pi/agent/settings.json           agent/settings.json
cp -r ~/.pi/agent/skills/bulletproof   agent/skills/
cp ~/.pi/agent/prompts/*.md            agent/prompts/
cp ~/.pi/agent/agents/*.md             agent/agents/ 2>/dev/null || true

git add -A && git commit -m "Update pi config" && git push
```

On other machines, `git pull` and re-run the setup script (it's idempotent — safe to run repeatedly).

---

## 🧩 Notes & tips

- **Version pinning:** packages in `settings.json` are **pinned** to exact versions for
  reproducible installs — every machine gets the identical set. Pinned specs are skipped by
  `pi update --extensions`/`--all`, so they won't silently drift. To upgrade one, edit its
  version here (or run `pi install npm:<pkg>@<newversion>`) and re-commit.
- **Per-project config:** for team-shared setups, pi also reads `.pi/settings.json` committed
  into a project repo — a separate mechanism from this global config.
- **MCP servers** (`pi-mcp-adapter`) may need their own config and API keys — handle those as
  secrets too, not in this repo.
- The scripts are **idempotent**: they back up any existing `auth.json` and merge (not wipe)
  your skills/prompts/agents.
- **Prerequisite:** Node.js >= 18 and npm must already be installed.
