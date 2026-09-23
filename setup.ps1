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

# pi-fff.json - fff runs in "override" mode so the built-in grep/find tool NAMES
# resolve to the fast, git-aware fff implementations. Every agent allowlist that
# already says "grep, find" then gets them with no frontmatter changes.
$fffSrc = Join-Path $RepoDir 'agent\pi-fff.json'
if (Test-Path $fffSrc) { Copy-Item $fffSrc (Join-Path $PiDir 'pi-fff.json') -Force }

# skills / prompts / agents / chains / extensions (merge, don't wipe)
foreach ($d in @('skills','prompts','agents','chains','extensions')) {
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

# ---- 5b. bulletproof system prompt + `bpi` command -------------------
# The installer ships prompts/bulletproof.md (slash launcher) + agents, but NOT
# the system prompt used by --append-system-prompt. Generate it from the agent
# file (strip the YAML frontmatter), then install a `bpi` function in $PROFILE.
$bpAgent = Join-Path $PiDir 'agents\bulletproof.md'
$bpSys   = Join-Path $PiDir 'prompts\bulletproof.system.md'
if (Test-Path $bpAgent) {
  $lines = Get-Content $bpAgent
  $fm = 0; $body = New-Object System.Collections.Generic.List[string]
  foreach ($ln in $lines) {
    if ($fm -lt 2) { if ($ln -eq '---') { $fm++ }; continue }
    $body.Add($ln)
  }
  Set-Content -Path $bpSys -Value $body -Encoding UTF8
  Say 'Generated bulletproof.system.md for --append-system-prompt launches'
} else {
  Warn 'agents/bulletproof.md not found; skipped bulletproof.system.md generation'
}

# Idempotently add the `bpi` function to the PowerShell profile.
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Force -Path $PROFILE | Out-Null }
if (Select-String -Path $PROFILE -Pattern '>>> bulletproof bpi >>>' -Quiet) {
  Say 'bpi already present in $PROFILE'
} else {
  $bpiBlock = @'

# >>> bulletproof bpi >>>
# Run the drift-proof bulletproof agent: bpi "<req>" | bpi -Fast "..." | bpi -Full "..."
function bpi {
    param([switch]$Fast, [switch]$Full,
          [Parameter(ValueFromRemainingArguments=$true)][string[]]$Prompt)
    $sys  = "$HOME/.pi/agent/prompts/bulletproof.system.md"
    $text = ($Prompt -join " ")
    if ($Fast) { $text = "mode: fast`n$text" } elseif ($Full) { $text = "mode: full`n$text" }
    if ([string]::IsNullOrWhiteSpace($text)) { pi --append-system-prompt $sys }
    else { pi --append-system-prompt $sys $text }
}
# <<< bulletproof bpi <<<
'@
  Add-Content -Path $PROFILE -Value $bpiBlock
  Say 'Added bpi function to $PROFILE'
}

# ---- 6. done ----------------------------------------------------------
Write-Host @'

============================================================
  pi setup complete.

  ONE MANUAL STEP REMAINS - authentication (never committed):
    1. Run:  pi
    2. Log in to your provider:  /login
       (this machine uses github-copilot by default)

  Reload shell for bpi:  . $PROFILE
  Use bulletproof:       bpi "<requirement>"  (or bpi -Fast / -Full)
  Verify packages:       pi list
  Refresh models:        pi update --models
============================================================
'@ -ForegroundColor Green
