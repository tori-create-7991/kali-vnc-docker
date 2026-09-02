#!/usr/bin/env bash
set -euo pipefail

VNC_DIR="/root/.vnc"
PASSWD_FILE="$VNC_DIR/passwd"
XSTARTUP="$VNC_DIR/xstartup"
DISPLAY_NUM="${VNC_DISPLAY:-:1}"
GEOMETRY="${VNC_GEOMETRY:-1280x800}"
DEPTH="${VNC_DEPTH:-24}"

log() { echo "[entrypoint] $*"; }

mkdir -p "$VNC_DIR"
chmod 700 "$VNC_DIR"

if [[ -n "${VNC_PASSWORD:-}" ]]; then
  log "VNC_PASSWORD is set via environment variable. Applying it."
  PASSWORD="$VNC_PASSWORD"
  SHOW_ONCE=0
elif [[ -f "$PASSWD_FILE" ]]; then
  log "No VNC_PASSWORD given; reusing existing password file from persisted volume."
  PASSWORD=""
  SHOW_ONCE=0
else
  log "No VNC_PASSWORD given and no existing password file; generating a random one."
  PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 8 || true)"
  SHOW_ONCE=1
fi

if [[ -n "${PASSWORD:-}" ]]; then
  printf '%s\n%s\n' "$PASSWORD" "$PASSWORD" | vncpasswd "$PASSWD_FILE" >/dev/null
  chmod 600 "$PASSWD_FILE"

  if [[ "$SHOW_ONCE" == "1" ]]; then
    echo "=================================================="
    echo " Generated VNC password (shown once, not logged again):"
    echo "   $PASSWORD"
    echo " Screen Sharing / VNC client: vnc://localhost:5901"
    echo "=================================================="
  fi
fi

if [[ ! -f "$XSTARTUP" ]]; then
  cat > "$XSTARTUP" <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
  chmod +x "$XSTARTUP"
fi

vncserver -kill "$DISPLAY_NUM" >/dev/null 2>&1 || true
rm -f "/tmp/.X${DISPLAY_NUM#:}-lock" "/tmp/.X11-unix/X${DISPLAY_NUM#:}" 2>/dev/null || true

log "Starting vncserver on display ${DISPLAY_NUM} (${GEOMETRY}, depth ${DEPTH})..."
vncserver "$DISPLAY_NUM" -geometry "$GEOMETRY" -depth "$DEPTH"

# このTightVNC(1.3.10)のvncserverスクリプトは-fg(foreground)非対応で、常にデーモン化する。
# コンテナのPID1をvncserverログのtailにし、フォアグラウンドプロセスとして維持する。
LOG_FILE="$VNC_DIR/$(hostname)${DISPLAY_NUM}.log"
log "vncserver started (daemonized). Tailing ${LOG_FILE} to keep the container alive..."
exec tail -F "$LOG_FILE"
