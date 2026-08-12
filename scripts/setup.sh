#!/usr/bin/env bash
# scripts/setup.sh — Install and boot OmniRoute gateway
# Usage: scripts/setup.sh [--compose] [--health-timeout SECS]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# --- Defaults ---
COMPOSE_MODE=false
HEALTH_TIMEOUT=30
OMNIROUTE_PORT="${OMNIROUTE_PORT:-20128}"
OMNIROUTE_VERSION="${OMNIROUTE_VERSION:-3.8.49}"

# --- Parse flags ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --compose)        COMPOSE_MODE=true; shift ;;
    --health-timeout) HEALTH_TIMEOUT="$2"; shift 2 ;;
    *) echo "ERROR: Unknown flag: $1"; exit 1 ;;
  esac
done

# --- Helpers ---
info()  { echo "INFO:  $*"; }
warn()  { echo "WARN:  $*"; }
error() { echo "ERROR: $*"; exit 1; }

check_port() {
  if ss -tlnp 2>/dev/null | grep -q ":${OMNIROUTE_PORT} "; then
    return 0  # port in use
  fi
  return 1  # port free
}

health_poll() {
  local timeout="$1"
  local elapsed=0
  info "Waiting for OmniRoute health on :${OMNIROUTE_PORT} (timeout: ${timeout}s)..."
  while (( elapsed < timeout )); do
    if curl -sf "http://localhost:${OMNIROUTE_PORT}/v1/models" >/dev/null 2>&1; then
      info "Gateway healthy at http://localhost:${OMNIROUTE_PORT}/v1"
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

# --- Check Node version (npm path only) ---
check_node() {
  if ! command -v node &>/dev/null; then
    error "Node.js not found — install Node >= 22.22.2 (exit 2)"
  fi
  local node_version
  node_version="$(node -v | sed 's/^v//')"
  local major minor
  major="$(echo "$node_version" | cut -d. -f1)"
  minor="$(echo "$node_version" | cut -d. -f2)"
  if (( major < 22 )) || { (( major == 22 )) && (( minor < 22 )); }; then
    error "Node $node_version detected — need >= 22.22.2 (exit 2)"
  fi
  info "Node $node_version OK"
}

# --- Check Docker (compose path only) ---
check_docker() {
  if ! command -v docker &>/dev/null; then
    error "Docker not found — use the npm path (no --compose) (exit 2)"
  fi
  if ! docker info &>/dev/null; then
    error "Docker daemon not running (exit 2)"
  fi
  info "Docker OK"
}

# --- Check for existing healthy OmniRoute ---
check_existing() {
  if check_port; then
    if curl -sf "http://localhost:${OMNIROUTE_PORT}/v1/models" >/dev/null 2>&1; then
      info "OmniRoute already healthy on :${OMNIROUTE_PORT} — nothing to do"
      exit 0
    else
      warn "Port ${OMNIROUTE_PORT} in use but OmniRoute unhealthy — will attempt restart"
    fi
  fi
}

# --- NPM install path ---
install_npm() {
  check_node
  check_existing

  if command -v omniroute &>/dev/null; then
    local installed_version
    installed_version="$(omniroute --version 2>/dev/null || echo "unknown")"
    if [[ "$installed_version" != "$OMNIROUTE_VERSION" ]]; then
      warn "OmniRoute $installed_version installed, pinning $OMNIROUTE_VERSION"
    fi
  fi

  info "Installing omniroute@${OMNIROUTE_VERSION} globally..."
  npm install -g "omniroute@${OMNIROUTE_VERSION}"

  info "Starting OmniRoute..."
  omniroute &
  local pid=$!
  trap "kill $pid 2>/dev/null || true" EXIT

  if ! health_poll "$HEALTH_TIMEOUT"; then
    error "OmniRoute failed health check after ${HEALTH_TIMEOUT}s — check logs"
  fi
}

# --- Docker Compose path ---
install_compose() {
  check_docker

  if check_port; then
    if curl -sf "http://localhost:${OMNIROUTE_PORT}/v1/models" >/dev/null 2>&1; then
      info "OmniRoute already healthy on :${OMNIROUTE_PORT} — nothing to do"
      exit 0
    fi
  fi

  info "Starting OmniRoute via Docker Compose..."
  docker compose -f "${REPO_DIR}/docker-compose.omniroute.yml" up -d

  if ! health_poll "$HEALTH_TIMEOUT"; then
    error "Docker Compose health check failed after ${HEALTH_TIMEOUT}s"
  fi
}

# --- Main ---
info "OmniRoute Gateway Setup (v${OMNIROUTE_VERSION})"
info "Port: ${OMNIROUTE_PORT}"

if [[ "$COMPOSE_MODE" == true ]]; then
  install_compose
else
  install_npm
fi

info ""
info "OmniRoute Dashboard: http://localhost:${OMNIROUTE_PORT}/dashboard"
info ""
info "Setup complete. Next step:"
info "  ./scripts/configure-hermes.sh"
