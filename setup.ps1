# ============================================================
#  pi setup - Windows (PowerShell)
#  Installs pi, restores portable config, installs packages,
#  and sets up the browser-debug Chromium binary.
#
#  Usage:  powershell -ExecutionPolicy Bypass -File .\setup.ps1
# ============================================================
$ErrorActionPreference = 'Stop'

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PiDir   = Join-Path $HOME '.pi\agent'

function Say  ($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Warn ($m) { Write-Host "[!] $m" -ForegroundColor Yellow }

# ---- 0. prerequisites -------------------------------------------------
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Warn 'Node.js is required. Install Node >= 18 first.'; exit 1 }
if (-not (Get-Command npm  -ErrorAction SilentlyContinue)) { Warn 'npm is required.'; exit 1 }

# ---- 1. install pi ----------------------------------------------------
Say 'Installing pi (latest)...'
npm install -g --ignore-scripts '@earendil-works/pi-coding-agent@latest'

# ---- 2. restore portable config --------------------------------------
Say "Restoring portable config into $PiDir..."
New-Item -ItemType Directory -Force -Path $PiDir | Out-Null

# Preserve an existing auth.json (secrets are never in this repo)
$authPath = Join-Path $PiDir 'auth.json'
if (Test-Path $authPath) {
  Copy-Item $authPath "$authPath.bak" -Force
  Say 'Existing auth.json backed up to auth.json.bak'
}

# settings.json
Copy-Item (Join-Path $RepoDir 'agent\settings.json') (Join-Path $PiDir 'settings.json') -Force

# skills / prompts / agents / chains (merge, don't wipe)
foreach ($d in @('skills','prompts','agents','chains')) {
  $src = Join-Path $RepoDir "agent\$d"
  if (Test-Path $src) {
    $dst = Join-Path $PiDir $d
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    Copy-Item "$src\*" $dst -Recurse -Force
  }
}

# ---- 3. install pi packages from settings.json -----------------------
Say 'Installing pi packages listed in settings.json...'
try { pi update --all } catch { Warn 'pi update --all returned non-zero; check output above.' }

# ---- 4. browser-debug: Chromium binary -------------------------------
if (Select-String -Path (Join-Path $PiDir 'settings.json') -Pattern 'pi-browser-debug' -Quiet) {
  Say 'Installing Playwright Chromium for pi-browser-debug...'
  Push-Location (Join-Path $PiDir 'npm')
  try { npx playwright install chromium }
  catch { Warn "Playwright Chromium install failed; run 'npx playwright install chromium' manually." }
  finally { Pop-Location }
}

# ---- 5. bulletproof skill + agent (pinned via its own installer) -----
$BulletproofRef = if ($env:BULLETPROOF_REF) { $env:BULLETPROOF_REF } else { 'v0.8.0-rc.2' }
Say "Installing bulletproof ($BulletproofRef) - skill + agents..."
try {
  $env:BULLETPROOF_REF = $BulletproofRef
  & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/shankar029/bulletproof/$BulletproofRef/install.ps1"))) pi
} catch { Warn 'bulletproof install failed; re-run its installer manually.' }

# ---- 6. done ----------------------------------------------------------
Write-Host @'

============================================================
  pi setup complete.

  ONE MANUAL STEP REMAINS - authentication (never committed):
    1. Run:  pi
    2. Log in to your provider:  /login
       (this machine uses github-copilot by default)

  Verify packages:   pi list
  Refresh models:    pi update --models
============================================================
'@ -ForegroundColor Green
