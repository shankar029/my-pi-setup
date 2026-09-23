#!/usr/bin/env bash
# ============================================================
#  pi setup — Linux / macOS
#  Installs pi, restores portable config, installs packages,
#  and sets up the browser-debug Chromium binary.
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_DIR="${HOME}/.pi/agent"

say() { printf '\033[1;36m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }

# ---- 0. prerequisites -------------------------------------------------
command -v node >/dev/null 2>&1 || {
  warn "Node.js is required. Install Node >= 18 first."
  exit 1
}
command -v npm >/dev/null 2>&1 || {
  warn "npm is required."
  exit 1
}

# ---- 1. install pi ----------------------------------------------------
say "Installing pi (latest)…"
npm install -g --ignore-scripts @earendil-works/pi-coding-agent@latest

# ---- 2. restore portable config --------------------------------------
say "Restoring portable config into ${PI_DIR}…"
mkdir -p "${PI_DIR}"

# Preserve an existing auth.json (secrets are never in this repo)
if [ -f "${PI_DIR}/auth.json" ]; then
  cp "${PI_DIR}/auth.json" "${PI_DIR}/auth.json.bak"
  say "Existing auth.json backed up to auth.json.bak"
fi

# settings.json — merge-safe: only overwrite if repo copy exists
cp -f "${REPO_DIR}/agent/settings.json" "${PI_DIR}/settings.json"

# pi-fff.json — fff runs in "override" mode so the built-in grep/find tool NAMES
# resolve to the fast, git-aware fff implementations. Every agent allowlist that
# already says "grep, find" then gets them with no frontmatter changes.
if [ -f "${REPO_DIR}/agent/pi-fff.json" ]; then
  cp -f "${REPO_DIR}/agent/pi-fff.json" "${PI_DIR}/pi-fff.json"
fi

# skills / prompts / agents / chains / extensions — copy (merge, don't wipe)
for d in skills prompts agents chains extensions; do
  if [ -d "${REPO_DIR}/agent/${d}" ]; then
    mkdir -p "${PI_DIR}/${d}"
    cp -rf "${REPO_DIR}/agent/${d}/." "${PI_DIR}/${d}/"
  fi
done

# ---- 3. install pi packages from settings.json -----------------------
say "Installing pi packages listed in settings.json…"
pi update --all || warn "pi update --all returned non-zero; check output above."

# ---- 4. browser-debug: Chromium binary -------------------------------
if grep -q "pi-browser-debug" "${PI_DIR}/settings.json"; then
  say "Installing Playwright Chromium for pi-browser-debug…"
  (cd "${PI_DIR}/npm" && npx playwright install chromium) ||
    warn "Playwright Chromium install failed; run 'npx playwright install chromium' manually."
fi

# ---- 5. bulletproof skill + agent (pinned via its own installer) -----
BULLETPROOF_REF="${BULLETPROOF_REF:-v0.8.0-rc.2}"
say "Installing bulletproof (${BULLETPROOF_REF}) — skill + agents…"
curl -fsSL "https://raw.githubusercontent.com/shankar029/bulletproof/${BULLETPROOF_REF}/install.sh" |
  BULLETPROOF_REF="${BULLETPROOF_REF}" sh -s -- pi ||
  warn "bulletproof install failed; re-run its installer manually."

# ---- 5b. bulletproof system prompt + `bpi` shell command -------------
# The installer ships prompts/bulletproof.md (slash launcher) + agents, but NOT
# the system prompt used by --append-system-prompt. Generate it from the agent
# file (strip the YAML frontmatter), then install a `bpi` shell function.
BP_AGENT="${PI_DIR}/agents/bulletproof.md"
BP_SYS="${PI_DIR}/prompts/bulletproof.system.md"
if [ -f "${BP_AGENT}" ]; then
  awk 'BEGIN{fm=0}/^---$/{fm++;next}fm>=2' "${BP_AGENT}" > "${BP_SYS}"
  say "Generated bulletproof.system.md for --append-system-prompt launches"
else
  warn "agents/bulletproof.md not found; skipped bulletproof.system.md generation"
fi

# Idempotently add the `bpi` function to the user's shell profile(s).
install_bpi() { # $1 = profile file
  prof="$1"
  [ -f "${prof}" ] || : > "${prof}"
  if grep -q '>>> bulletproof bpi >>>' "${prof}" 2>/dev/null; then
    say "bpi already present in $(basename "${prof}")"
    return
  fi
  cat >> "${prof}" <<'BPI'

# >>> bulletproof bpi >>>
# Run the drift-proof bulletproof agent: bpi "<req>" | bpi --fast "..." | bpi --full "..."
bpi() {
  sys="${HOME}/.pi/agent/prompts/bulletproof.system.md"
  pfx=""
  case "$1" in
    --fast|-Fast|fast) pfx="mode: fast"; shift ;;
    --full|-Full|full) pfx="mode: full"; shift ;;
  esac
  text="$*"
  [ -n "$pfx" ] && text="$(printf '%s\n%s' "$pfx" "$text")"
  if [ -z "$text" ]; then pi --append-system-prompt "$sys"
  else pi --append-system-prompt "$sys" "$text"; fi
}
# <<< bulletproof bpi <<<
BPI
  say "Added bpi function to $(basename "${prof}")"
}
install_bpi "${HOME}/.bashrc"
[ -f "${HOME}/.zshrc" ] && install_bpi "${HOME}/.zshrc"

# ---- 6. done ----------------------------------------------------------
cat <<'EOF'

============================================================
  ✅ pi setup complete.

  ONE MANUAL STEP REMAINS — authentication (never committed):
    1. Run:  pi
    2. Log in to your provider:  /login
       (this machine uses github-copilot by default)

  Verify packages:   pi list
  Refresh models:    pi update --models

  Reload shell for bpi:  source ~/.bashrc   (or ~/.zshrc)
  Use bulletproof:       bpi "<requirement>"   (or: bpi --fast / --full)
============================================================
EOF
