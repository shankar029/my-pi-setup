#!/usr/bin/env bash
# ============================================================
#  pi setup — Linux / macOS
#  Installs pi, restores portable config, installs packages,
#  and sets up the browser-debug Chromium binary.
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_DIR="${HOME}/.pi/agent"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }

# ---- 0. prerequisites -------------------------------------------------
command -v node >/dev/null 2>&1 || { warn "Node.js is required. Install Node >= 18 first."; exit 1; }
command -v npm  >/dev/null 2>&1 || { warn "npm is required."; exit 1; }

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

# skills / prompts / agents / chains — copy (merge, don't wipe)
for d in skills prompts agents chains; do
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
  ( cd "${PI_DIR}/npm" && npx playwright install chromium ) || \
    warn "Playwright Chromium install failed; run 'npx playwright install chromium' manually."
fi

# ---- 5. done ----------------------------------------------------------
cat <<'EOF'

============================================================
  ✅ pi setup complete.

  ONE MANUAL STEP REMAINS — authentication (never committed):
    1. Run:  pi
    2. Log in to your provider:  /login
       (this machine uses github-copilot by default)

  Verify packages:   pi list
  Refresh models:    pi update --models
============================================================
EOF
