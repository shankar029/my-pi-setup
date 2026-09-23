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

```text
pi
/login        # log in to your provider (default: github-copilot)
```

That's it.

---

## 📦 What gets installed

The setup script:

1. Installs pi globally: `npm install -g --ignore-scripts @earendil-works/pi-coding-agent@latest`
2. Copies the portable config (`settings.json`, `pi-fff.json`) and the `extensions/` tree from
   [`agent/`](agent/) into `~/.pi/agent/`
3. Runs `pi update --all`, which reads `settings.json` and installs every listed package
4. Installs the Playwright **Chromium** binary (needed by `pi-browser-debug`)
5. Installs the **bulletproof** skill + agents via its own installer, resolving the **latest
   release tag — prereleases included** (override with `BULLETPROOF_REF`)
6. Generates `bulletproof.system.md` and adds a **`bpi`** shell command to your profile
   (PowerShell `$PROFILE` on Windows, `~/.bashrc`/`~/.zshrc` on Linux/macOS)

### Packages (from `agent/settings.json`)

| Package | Purpose |
| --- | --- |
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

- **Extension: `search-guard`** — blocks pathological repo-wide shell searches *before they run*
  and tells the model what to use instead. Lives in
  [`agent/extensions/search-guard/`](agent/extensions/search-guard/).

  It exists because a subagent researching a ~7.5k-file repo issued
  `grep -rn "<pattern>" --include=* -l . | grep -v node_modules` — `--include=*` matches every
  file (including a committed 29MB installer) and the `grep -v` filter runs far too late. It
  never returned, the per-tool deadline fired at 300s, and the whole research phase was lost.
  Prompt rules did **not** prevent this: the agent had a working fast `grep` tool, used it
  successfully earlier in the same run, and shelled out anyway. So this is a hard block.

  | Command | Time on that repo |
  |---|---|
  | `grep -rn ... --include=* .` | **>300s, killed** |
  | `rg` (default) | 32.2s |
  | `rg -t cs -t ts -t js` | 1.0s |
  | `rg <subtree>` | 0.3s |
  | `grep` tool (fff) | instant |

  Blocks `grep -r`/`--recursive`, `--include=*`, `find .`/`find /`, `ls -R`, `dir /s`. Allows
  `git grep`, non-recursive `grep`, `grep` used as a pipe filter, and `find -maxdepth ≤3`.
  Escape hatch: append `#allow-slow-search` to the command. Rule logic is dependency-free in
  `rules.ts` with a 35-case suite — run it with `npx tsx rules.test.mjs`.

  **It also bounds every bash call.** pi's `bash` tool declares `timeout` as optional with *no
  default*, so any command that never returns wedges its agent permanently: the tool never
  settles, `tool_execution_end` never fires, the child never reaches `agent_end`, and the parent
  waits forever with no signal. Blocking the search patterns we can name does nothing for a
  locked NuGet cache, a proxied `npm ci`, or a git operation waiting on credentials. So the hook
  fills in a wall-clock bound when the model didn't supply one — **300s** ordinarily, **1800s**
  for builds, installs and test suites (`npm ci`, `dotnet build|test`, `pytest`, `playwright`,
  `docker build`, …). An explicit model-supplied `timeout` always wins. Verified live: an
  unbounded `sleep 600` is now killed at 300s instead of hanging.

- **`pi-fff` in `override` mode** ([`agent/pi-fff.json`](agent/pi-fff.json)) — fff registers
  itself under the built-in tool names `grep`/`find`/`multi_grep` instead of
  `ffgrep`/`fffind`. Every agent whose allowlist already says `tools: read, grep, find, ...`
  silently gets the fast, git-aware, frecency-ranked implementations with **no frontmatter
  changes** — including subagents you don't control. This is the layer that makes the fast path
  the *default* path; `search-guard` is the layer that makes the slow path impossible.

  Also worth adding per-repo: an `.ignore` file (ripgrep/fd/fff honour it) excluding committed
  binaries and build output. On the repo above that alone cut `rg` from 32.2s to 4.1s.

- **Skill + Agent:** `bulletproof` — end-to-end production-quality delivery workflow, installed
  from [shankar029/bulletproof](https://github.com/shankar029/bulletproof) via its own installer
  (resolved to the **latest release tag, prereleases included**). This version ships **both** the
  `/bulletproof` skill **and** a
  drift-proof `bulletproof` agent plus 4 role subagents (`-researcher`, `-design-reviewer`,
  `-verifier`, `-reviewer`). Not vendored here — the upstream installer is the source of truth,
  so a new machine always gets the current release.
  - Run as skill: `/bulletproof <requirement>` (or `/skill:bulletproof`)
  - Run as agent (drift-proof): the setup adds a **`bpi`** command —
    `bpi "<requirement>"`, `bpi -Fast "..."` / `-Full "..."` (PowerShell) or
    `bpi --fast "..."` / `--full "..."` (bash/zsh). It launches
    `pi --append-system-prompt ~/.pi/agent/prompts/bulletproof.system.md`.
  - Or via the `Agent` tool → `subagent_type: bulletproof`.

### The `bpi` command

The setup script wires a `bpi` function into your shell profile so you can run the drift-proof
bulletproof **agent** without typing the full `--append-system-prompt` line:

| Shell | Usage |
| --- | --- |
| PowerShell | `bpi "add rate limiting to /login"` · `bpi -Fast "..."` · `bpi -Full "..."` |
| bash / zsh | `bpi "add rate limiting to /login"` · `bpi --fast "..."` · `bpi --full "..."` |

`-Fast`/`--fast` forces the inline short path (no subagents); `-Full`/`--full` forces the full
six-phase loop with delegation. After setup, reload your shell (`. $PROFILE` or
`source ~/.bashrc`) once before first use. `bulletproof.system.md` is generated from the
installed `agents/bulletproof.md` (it is not shipped by the installer directly).

---

## 🗂️ Repo layout

```text
my-pi-setup/
├── README.md
├── .gitignore              # keeps secrets & caches out of git
├── setup.ps1               # Windows installer
├── setup.sh                # Linux / macOS installer
└── agent/                  # portable config → copied to ~/.pi/agent/
    ├── settings.json       # provider, model, theme, pinned package list
    ├── pi-fff.json         # fff "override" mode: grep/find ARE the fast tools
    └── extensions/
        └── search-guard/   # blocks repo-wide grep -r / find . before they run
            ├── index.ts        # tool_call hook: block slow scans + bound every bash call
            ├── rules.ts        # rule definitions + default timeouts, dependency-free
            └── rules.test.mjs  # 35 cases: npx tsx rules.test.mjs
```

> **bulletproof** is intentionally *not* vendored in `agent/`. It's installed on each machine
> from its upstream repo at the latest published tag, so the skill + agents always match a
> real release.

---

## 🔒 Security — what is NOT in this repo

The following are **git-ignored** and must be regenerated / re-entered per machine:

| Excluded | Why | How it's restored |
| --- | --- | --- |
| `auth.json` | 🔴 Live OAuth tokens / API keys | Run `/login` after setup |
| `npm/`, `git/` | Installed package code | `pi update --all` reinstalls from `settings.json` |
| `bin/` | Downloaded binaries (ripgrep, fd) | pi downloads on demand |
| `fff/`, `memory/`, `web-search-cache/` | Local caches | Rebuilt automatically |
| `sessions/`, `run-history.jsonl`, `models-store.json` | Machine-local history | `pi update --models` rebuilds the catalog |

> ⚠️ **Never commit `auth.json`.** If tokens ever land in git history, rotate them immediately.

---

## 🔄 Updating this setup

After changing packages/settings on your main machine, sync them back into the repo:

```bash
# from the repo root
cp ~/.pi/agent/settings.json  agent/settings.json
git add -A && git commit -m "Update pi config" && git push
```

**bulletproof** needs no bump — the setup resolves the newest published tag on every run.
Pin a specific one when you need to: `BULLETPROOF_REF=v0.8.0 ./setup.sh`
(PowerShell: `$env:BULLETPROOF_REF='v0.8.0'; .\setup.ps1`).

On other machines, `git pull` and re-run the setup script (it's idempotent — safe to run repeatedly).

---

## 🧩 Notes & tips

- **Version pinning:** packages in `settings.json` are **pinned** to exact versions for
  reproducible installs — every machine gets the identical set. Pinned specs are skipped by
  `pi update --extensions`/`--all`, so they won't silently drift. To upgrade one, edit its
  version here (or run `pi install npm:<pkg>@<newversion>`) and re-commit.
- **bulletproof versioning:** *not* pinned — the setup queries the GitHub releases API and takes
  the newest tag, **including prereleases**, so `rc` builds are picked up as soon as they ship.
  This deliberately uses `/releases?per_page=1` (newest-first, includes prereleases) rather than
  `/releases/latest`, which **excludes** prereleases and would currently resolve to `v0.7.0`
  instead of `v0.8.0-rc.2`. If the API is unreachable or rate-limited it falls back to `main`;
  set `BULLETPROOF_REF` to pin a specific tag.
- **Per-project config:** for team-shared setups, pi also reads `.pi/settings.json` committed
  into a project repo — a separate mechanism from this global config.
- **MCP servers** (`pi-mcp-adapter`) may need their own config and API keys — handle those as
  secrets too, not in this repo.
- The scripts are **idempotent**: they back up any existing `auth.json`, re-running the
  bulletproof installer refreshes the skill + agents in place, and the `bpi` block is added to
  your shell profile only once (guarded by a marker comment).
- **Prerequisite:** Node.js >= 18 and npm must already be installed.
