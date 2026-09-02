#!/usr/bin/env bash
# setup.sh — Docker Desktop から Colima への移行(べき等)
#
# Usage:
#   ./setup.sh [--stop-docker-desktop|--keep-docker-desktop]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'

info()    { echo -e "${BOLD}[setup]${RESET} $*"; }
success() { echo -e "${GREEN}[setup] OK $*${RESET}"; }
warn()    { echo -e "${YELLOW}[setup] !! $*${RESET}"; }
fail()    { echo -e "${RED}[setup] NG $*${RESET}"; exit 1; }

STOP_DESKTOP="${STOP_DOCKER_DESKTOP:-1}"
for arg in "$@"; do
  case "$arg" in
    --stop-docker-desktop) STOP_DESKTOP=1 ;;
    --keep-docker-desktop) STOP_DESKTOP=0 ;;
  esac
done

# ── Step 1: Homebrew check ──────────────────────────────────────────
info "Step 1: Checking Homebrew..."
command -v brew &>/dev/null || fail "Homebrew not found. Install it first: https://brew.sh"
success "Homebrew: $(brew --version | head -1)"

# ── Step 2: Install colima / docker / docker-compose (idempotent) ───
info "Step 2: Installing colima + standalone docker CLI..."
for pkg in colima docker docker-compose docker-credential-helper; do
  if brew list --formula "$pkg" &>/dev/null; then
    success "$pkg already installed"
  else
    info "  Installing $pkg..."
    brew install "$pkg"
  fi
done

# ── Step 3: credsStore -> osxkeychain (idempotent JSON edit) ────────
info "Step 3: Ensuring ~/.docker/config.json uses osxkeychain credential store..."
DOCKER_CONFIG="$HOME/.docker/config.json"
python3 - "$DOCKER_CONFIG" <<'PYEOF'
import json, sys, os, shutil, time

path = sys.argv[1]
if not os.path.exists(path):
    print("[setup] ~/.docker/config.json not found; creating with osxkeychain")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump({"credsStore": "osxkeychain"}, f, indent=2)
    sys.exit(0)

with open(path) as f:
    cfg = json.load(f)

if cfg.get("credsStore") == "osxkeychain":
    print("[setup] credsStore already osxkeychain; skipping")
    sys.exit(0)

backup = f"{path}.bak-{int(time.time())}"
shutil.copy2(path, backup)
cfg["credsStore"] = "osxkeychain"
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
print(f"[setup] credsStore -> osxkeychain (backup: {backup})")
PYEOF
success "credential store configured"

# ── Step 4: colima start (idempotent) ────────────────────────────────
info "Step 4: Starting colima (cpu=4 memory=8 disk=30 arch=aarch64)..."
if colima status &>/dev/null; then
  success "colima already running"
  warn "Resource flags only apply at VM creation. To change disk/memory/cpu, run 'colima delete' then re-run this script."
else
  colima start --cpu 4 --memory 8 --disk 30 --arch aarch64
  success "colima started"
fi

# ── Step 5: docker context ───────────────────────────────────────────
info "Step 5: Switching default docker context to colima..."
docker context use colima
success "docker context: $(docker context show)"

# ── Step 6: Stop Docker Desktop ──────────────────────────────────────
info "Step 6: Docker Desktop coexistence..."
if [[ "$STOP_DESKTOP" == "1" ]]; then
  if pgrep -x "Docker Desktop" &>/dev/null || pgrep -x "com.docker.backend" &>/dev/null; then
    osascript -e 'tell application "Docker Desktop" to quit' 2>/dev/null || true
    sleep 2
    success "Docker Desktop.app terminated"
  else
    success "Docker Desktop.app already not running"
  fi
  warn "Docker Desktop再起動後: Settings > General > 'Start Docker Desktop when you log in' のチェックを外してください(GUIからのみ確実にオフにできます)。"
else
  warn "Docker Desktopを残す方針です。切り替えは 'docker context use colima' / 'docker context use desktop-linux' を手動で。"
fi

# ── Step 7: Health check ─────────────────────────────────────────────
info "Step 7: Health check..."
colima status
docker version --format 'Client: {{.Client.Version}} / Server: {{.Server.Version}}' 2>/dev/null || warn "docker version check failed"
docker context ls

success "Setup complete."
