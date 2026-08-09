#!/usr/bin/env bash
# scripts/smoke-test.sh — 4-part integration test for Hermes + OmniRoute
# Usage: scripts/smoke-test.sh [--isolated] [--skip-hermes]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# --- Defaults ---
ISOLATED=false
SKIP_HERMES=false
OMNIROUTE_PORT="${OMNIROUTE_PORT:-20128}"
GATEWAY_URL="http://localhost:${OMNIROUTE_PORT}"
STREAM_TIMEOUT=15

# --- Parse flags ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --isolated)     ISOLATED=true; shift ;;
    --skip-hermes)  SKIP_HERMES=true; shift ;;
    *) echo "ERROR: Unknown flag: $1"; exit 1 ;;
  esac
done

# --- Helpers ---
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
declare -a RESULTS=()

pass() {
  local name="$1"
  echo "PASS  ${name}"
  RESULTS+=("PASS  ${name}")
  ((PASS_COUNT++))
}

fail() {
  local name="$1"
  local reason="$2"
  echo "FAIL  ${name} — ${reason}"
  RESULTS+=("FAIL  ${name} — ${reason}")
  ((FAIL_COUNT++))
}

skip() {
  local name="$1"
  local reason="$2"
  echo "SKIP  ${name} — ${reason}"
  RESULTS+=("SKIP  ${name} — ${reason}")
  ((SKIP_COUNT++))
}

summary() {
  local total=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
  echo "---"
  for r in "${RESULTS[@]}"; do
    echo "  $r"
  done
  echo "---"
  echo "Result: ${PASS_COUNT}/${total} passed, ${FAIL_COUNT} failed, ${SKIP_COUNT} skipped"
}

# --- Part 1: Non-streaming auto completion ---
test_auto_completion() {
  echo "Part 1: auto-completion (non-streaming)..."
  local response
  response="$(curl -sf -X POST "${GATEWAY_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "auto",
      "messages": [{"role": "user", "content": "Say hello in exactly one word."}],
      "stream": false
    }' 2>&1)" || {
    fail "auto-completion" "curl failed — is OmniRoute running on :${OMNIROUTE_PORT}?"
    return 1
  }

  # Check for content
  local content
  content="$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['choices'][0]['message']['content'])" 2>/dev/null || true)"
  if [[ -z "$content" ]]; then
    fail "auto-completion" "HTTP 200 but no content in response"
    return 1
  fi

  pass "auto-completion"
}

# --- Part 2: SSE streaming ---
test_sse_streaming() {
  echo "Part 2: sse-streaming..."
  local tmpfile
  tmpfile="$(mktemp)"

  # Use timeout to prevent hanging
  local got_chunks=false
  local got_done=false

  local http_code
  http_code="$(curl -sf -o "$tmpfile" -w "%{http_code}" -X POST "${GATEWAY_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "auto",
      "messages": [{"role": "user", "content": "Count from 1 to 3."}],
      "stream": true
    }' --max-time "$STREAM_TIMEOUT" 2>&1)" || {
    # curl non-zero but file may have partial content
    http_code="000"
  }

  if grep -q "data:" "$tmpfile" 2>/dev/null; then
    got_chunks=true
  fi
  if grep -q "\[DONE\]" "$tmpfile" 2>/dev/null; then
    got_done=true
  fi

  rm -f "$tmpfile"

  if [[ "$got_chunks" == true ]] && [[ "$got_done" == true ]]; then
    pass "sse-streaming"
  elif [[ "$got_chunks" == true ]]; then
    fail "sse-streaming" "SSE chunks arrived but no [DONE] terminator — stream may have stalled"
  elif [[ "$http_code" == "000" ]]; then
    fail "sse-streaming" "Request timed out after ${STREAM_TIMEOUT}s — check providers.<id>.request_timeout_seconds"
  else
    fail "sse-streaming" "No SSE data: chunks received"
  fi
}

# --- Part 3: Tool-calling ---
test_tool_calling() {
  echo "Part 3: tool-calling..."
  local response
  response="$(curl -sf -X POST "${GATEWAY_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "auto/coding",
      "messages": [{"role": "user", "content": "What is the weather in Tokyo?"}],
      "stream": false,
      "tools": [
        {
          "type": "function",
          "function": {
            "name": "get_weather",
            "description": "Get weather for a city",
            "parameters": {
              "type": "object",
              "properties": {
                "city": {"type": "string", "description": "City name"}
              },
              "required": ["city"]
            }
          }
        }
      ]
    }' 2>&1)" || {
    fail "tool-calling" "curl failed"
    return 1
  }

  # Check for tool_calls
  local has_tools
  has_tools="$(echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
msg = data['choices'][0]['message']
print('yes' if msg.get('tool_calls') else 'no')
" 2>/dev/null || echo "no")"

  if [[ "$has_tools" == "yes" ]]; then
    pass "tool-calling"
  else
    fail "tool-calling" "Model does not support tool calling — pin a tool-capable catalog model (e.g. google/gemini-2.5-flash)"
  fi
}

# --- Part 4: Hermes end-to-end ---
test_hermes_e2e() {
  echo "Part 4: hermes-e2e..."
  if ! command -v hermes &>/dev/null; then
    skip "hermes-e2e" "hermes not installed"
    return 0
  fi

  local hermes_args=()
  if [[ "$ISOLATED" == true ]]; then
    hermes_args+=("--config-dir" "${REPO_DIR}/.hermes-lab")
  fi

  local output
  output="$(hermes chat "${hermes_args[@]}" -q "Say hello" 2>&1)" || {
    fail "hermes-e2e" "hermes chat failed — ${output}"
    return 1
  }

  # Strip ANSI codes for clean check
  local clean
  clean="$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')"

  if [[ -z "$clean" ]] || [[ "$clean" =~ ^[[:space:]]*$ ]]; then
    fail "hermes-e2e" "Empty response from hermes chat"
  else
    pass "hermes-e2e"
  fi
}

# --- Main ---
echo "=== Hermes + OmniRoute Smoke Test ==="
echo "Gateway: ${GATEWAY_URL}"
echo ""

test_auto_completion || true
test_sse_streaming || true
test_tool_calling || true

if [[ "$SKIP_HERMES" == true ]]; then
  skip "hermes-e2e" "skipped by --skip-hermes"
else
  test_hermes_e2e || true
fi

echo ""
summary

if (( FAIL_COUNT > 0 )); then
  exit 5
fi
exit 0
