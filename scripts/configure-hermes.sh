#!/usr/bin/env bash
# scripts/configure-hermes.sh — Wire Hermes to OmniRoute custom endpoint
# Usage: scripts/configure-hermes.sh [--isolated] [--rollback]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# --- Defaults ---
ISOLATED=false
ROLLBACK=false
OMNIROUTE_PORT="${OMNIROUTE_PORT:-20128}"
MODEL_ID="${MODEL_ID:-auto}"

# --- Parse flags ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --isolated) ISOLATED=true; shift ;;
    --rollback) ROLLBACK=true; shift ;;
    *) echo "ERROR: Unknown flag: $1"; exit 1 ;;
  esac
done

# --- Helpers ---
info()  { echo "INFO:  $*"; }
warn()  { echo "WARN:  $*"; }
error() { echo "ERROR: $*"; exit 1; }

# --- Determine HERMES_HOME ---
if [[ "$ISOLATED" == true ]]; then
  HERMES_HOME="${REPO_DIR}/.hermes-lab"
  mkdir -p "$HERMES_HOME"
  info "Isolated mode — config dir: ${HERMES_HOME}"
else
  HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
  info "In-place mode — config dir: ${HERMES_HOME}"
fi

CONFIG_FILE="${HERMES_HOME}/config.yaml"

# --- Rollback path ---
if [[ "$ROLLBACK" == true ]]; then
  LATEST_BACKUP="$(ls -t "${CONFIG_FILE}".bak.* 2>/dev/null | head -1)"
  if [[ -z "$LATEST_BACKUP" ]]; then
    error "No backup found at ${CONFIG_FILE}.bak.* — nothing to restore"
  fi
  info "Restoring from ${LATEST_BACKUP}..."
  cp "$LATEST_BACKUP" "$CONFIG_FILE"
  if command -v hermes &>/dev/null; then
    if hermes config check &>/dev/null; then
      info "Rollback complete — hermes config check passes"
    else
      warn "Rollback restored but hermes config check failed — review config manually"
    fi
  else
    info "Rollback restored (hermes not installed, skipping config check)"
  fi
  exit 0
fi

# --- Backup before write ---
if [[ -f "$CONFIG_FILE" ]]; then
  BACKUP="${CONFIG_FILE}.bak.$(date +%s)"
  info "Backing up config to ${BACKUP}..."
  if ! cp "$CONFIG_FILE" "$BACKUP" 2>/dev/null; then
    error "Cannot create backup — aborting, nothing changed (exit 4)"
  fi
else
  info "No existing config at ${CONFIG_FILE} — creating new"
  mkdir -p "$(dirname "$CONFIG_FILE")"
fi

# --- Write model block ---
cat > "$CONFIG_FILE" <<YAML
model:
  default: ${MODEL_ID}
  provider: custom
  base_url: http://localhost:${OMNIROUTE_PORT}/v1
  api_key: ""
YAML

info "Config written to ${CONFIG_FILE}"

# --- Verify ---
if command -v hermes &>/dev/null; then
  info "Running hermes config check..."
  if hermes config check &>/dev/null; then
    info "hermes config check PASSED"
  else
    warn "hermes config check FAILED — rolling back"
    if [[ -n "${BACKUP:-}" ]] && [[ -f "${BACKUP}" ]]; then
      cp "$BACKUP" "$CONFIG_FILE"
      info "Rolled back to ${BACKUP}"
    fi
    error "Config verification failed (exit 4)"
  fi
else
  warn "hermes not installed — skipping config check (manual verify)"
fi

info ""
info "Configuration complete. Next step:"
info "  ./scripts/smoke-test.sh"
