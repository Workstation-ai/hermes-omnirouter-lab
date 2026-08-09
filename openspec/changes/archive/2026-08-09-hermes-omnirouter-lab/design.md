# Design: Hermes Agent ↔ OmniRoute Integration Lab

## Technical Approach

Bare-metal lab: npm-global OmniRoute (v3.8.49 — see Version Note) as default, Docker Compose as documented alternative. Three scripts (setup, configure, smoke) composed sequentially. Hermes config mutation isolated via backup+restore and optional `HERMES_HOME` override. All artifacts live in the repo — deleting the folder reverts the box.

## Architecture Decisions

### Decision: OmniRoute install method

**Choice**: npm global default, `--compose` flag for Docker alternative
**Alternatives considered**: Docker-only; pip/npx wrappers
**Rationale**: npm is zero-dependency on this box (Node 22.23.2 present); Docker is optional per scope. Compose alternative serves users who prefer containerized isolation.

### Decision: Default model ID

**Choice**: `auto` for demo (dynamic routing); document pinned ≥128k fallback (`google/gemini-2.5-flash`, context 1048576)
**Alternatives considered**: Hardcode a single model ID as default
**Rationale**: `auto` demonstrates OmniRoute's routing power; the ≥128k pin is the safety net when `auto` lands on a small-context model (Hermes minimum: 64k). The example config ships both paths.

### Decision: HERMES_HOME isolation strategy

**Choice**: Timestamped backup (`config.yaml.bak.<epoch>`) before in-place edit (default). `--isolated` flag creates `repo/.hermes-lab/` and sets `HERMES_HOME` for the smoke test only — never mutates `~/.hermes`.
**Alternatives considered**: Always isolated; no backup
**Rationale**: In-place is simpler for users who want the integration persistent. Isolation is opt-in for risk-averse users. Backup is mandatory in both paths.

### Decision: Version pin

**Choice**: Pin OmniRoute to v3.8.49 (latest on npm as of design time). Document that3.8.50 is aspirational — scripts check and warn on drift.
**Alternatives considered**: Pin to3.8.50 (non-existent)
**Rationale**:3.8.50 is not published. Scripts must work against reality. Version-check logic warns and offers downgrade/upgrade path.

### Decision: Script error handling

**Choice**: `set -euo pipefail` + `trap` for cleanup + numeric exit codes (0=ok, 1=general, 2=dependency missing, 3=port conflict, 4=config error, 5=test failure)
**Alternatives considered**: Per-script ad-hoc checks
**Rationale**: Uniform error taxonomy lets the smoke test and README map exit codes to mitigations.

## Data Flow

```
User runs setup.sh
  → npm install -g omniroute@3.8.49 (or docker compose up)
  → Polls GET http://localhost:20128/v1/models (200 = healthy)
  → Prints endpoint + next step

User runs configure-hermes.sh
  → Backs up ~/.hermes/config.yaml → config.yaml.bak.<epoch>
  → Writes model block: provider: custom, base_url: http://localhost:20128/v1
  → Runs `hermes config check` → pass/fail

User runs smoke-test.sh
  → Part 1: curl POST /v1/chat/completions (auto, non-streaming) → assert 200 + content
  → Part 2: curl POST /v1/chat/completions (streaming) → assert SSE chunks + [DONE]
  → Part 3: curl POST /v1/chat/completions (tools array) → assert tool_calls present
  → Part 4: hermes chat -p "hello" → assert non-empty response
  → Summary + exit code
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `scripts/setup.sh` | Create | Install/boot OmniRoute, health check, idempotent |
| `scripts/configure-hermes.sh` | Create | Backup, write model block, verify, isolation flag |
| `scripts/smoke-test.sh` | Create | 4-part integration test, fail-fast, exit codes |
| `config/hermes-omnirouter.example.yaml` | Create | Annotated model block for copy-paste |
| `.env.example` | Create | OmniRoute env vars template |
| `docker-compose.omniroute.yml` | Create | Pinned v3.8.49, ports 20128/20129, health check |
| `docs/EDGE_CASES.md` | Create | 6 edge cases with symptom/cause/mitigation |
| `README.md` | Create | Quickstart, topology, troubleshooting |

## Script Interfaces

### setup.sh

```
Usage: scripts/setup.sh [--compose] [--health-timeout SECS]

Flags:
  --compose          Use Docker Compose instead of npm global install
  --health-timeout   Seconds to wait for /v1/models (default: 30)

Env vars:
  OMNIROUTE_PORT     Override gateway port (default: 20128)
  OMNIROUTE_VERSION  Override pinned version (default: 3.8.49)

Exit codes:
  0  Success — gateway healthy
  1  General error
  2  Dependency missing (Node < 22.22.2 or Docker not found)
  3  Port conflict (20128 already in use by non-OmniRoute process)

Idempotency:
  - Detects existing OmniRoute install → skips reinstall, checks health
  - Detects healthy OmniRoute on port → exits 0 immediately
  - Detects unhealthy OmniRoute → restarts and re-checks
```

### configure-hermes.sh

```
Usage: scripts/configure-hermes.sh [--isolated] [--rollback]

Flags:
  --isolated    Use HERMES_HOME=<repo>/.hermes-lab instead of ~/.hermes
  --rollback    Restore latest .bak.* backup and exit

Env vars:
  HERMES_HOME   Override Hermes config directory (alternative to --isolated)
  MODEL_ID      Override pinned model (default: auto)

Exit codes:
  0  Success — config written, hermes config check passes
  1  General error
  4  Config error (backup failed, hermes config check failed)

Backup strategy:
  - Timestamped: config.yaml.bak.<epoch>
  - Created BEFORE any write
  - Aborts if backup fails (nothing modified)
  - --rollback finds latest .bak.* and restores
```

### smoke-test.sh

```
Usage: scripts/smoke-test.sh [--isolated] [--skip-hermes]

Flags:
  --isolated     Run hermes chat against isolated HERMES_HOME
  --skip-hermes  Skip Part 4 (hermes chat) — test gateway only

Parts (fail-fast, each named):
  Part 1: auto-completion    — non-streaming, keyless, assert 200 + content
  Part 2: sse-streaming      — streaming, assert data: chunks + [DONE]
  Part 3: tool-calling       — tools array, assert tool_calls present
  Part 4: hermes-e2e         — hermes chat -p "hello", assert response

Exit codes:
  0   All parts pass
  5   One or more parts fail (summary printed)
  255 Skipped (dependency not met)

Output format:
  PASS  auto-completion
  PASS  sse-streaming
  FAIL  tool-calling — model lacks tool support
  ---
  Result: 2/3 passed
```

## Docker Compose Configuration

```yaml
# docker-compose.omniroute.yml
services:
  omniroute:
    image: diegosouzapw/omniroute:3.8.49
    ports:
      - "127.0.0.1:20128:20128"
      - "127.0.0.1:20129:20129"
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:20128/v1/models"]
      interval: 5s
      timeout: 3s
      retries: 6
    restart: unless-stopped
```

## Example Hermes Config

```yaml
# config/hermes-omnirouter.example.yaml
# Copy relevant sections into ~/.hermes/config.yaml
# Or use: scripts/configure-hermes.sh (handles backup + write automatically)

model:
  # Option A: auto-routing (demo, dynamic model selection)
  default: auto
  # Option B: pinned ≥128k (recommended for production)
  # default: google/gemini-2.5-flash
  provider: custom
  base_url: http://localhost:20128/v1
  api_key: ""  # keyless — OmniRoute default
  # context_length: 1048576  # uncomment for pinned model (gemini-2.5-flash)

# Auxiliary tasks route through the same endpoint by default.
# Override per-task if the routed model lacks capability:
# auxiliary:
#   compression:
#     provider: custom
#     # model: google/gemini-2.5-flash  # needs ≥ main context
```

## Default Model Selection

The default is `auto` for demonstration purposes. For stable/reproducible use, pin `google/gemini-2.5-flash` (1M context, free tier). Alternative ≥128k options available through OmniRoute: `meta-llama/llama-3.3-70b-versatile` (128k), `openai/gpt-4o-mini` (128k).

## HERMES_HOME Isolation Strategy

```
Default (in-place):
  1. cp ~/.hermes/config.yaml ~/.hermes/config.yaml.bak.<epoch>
  2. Write model block to ~/.hermes/config.yaml
  3. hermes config check
  4. On failure: cp ~/.hermes/config.yaml.bak.<epoch> ~/.hermes/config.yaml

Isolated (--isolated):
  1. mkdir -p repo/.hermes-lab
  2. cp ~/.hermes/config.yaml repo/.hermes-lab/config.yaml (reference only)
  3. Write model block to repo/.hermes-lab/config.yaml
  4. HERMES_HOME=repo/.hermes-lab hermes chat -p "hello"
  5. ~/.hermes untouched (byte-identical before/after)

Rollback (--rollback):
  1. ls -t ~/.hermes/config.yaml.bak.* | head -1 → latest backup
  2. cp latest ~/.hermes/config.yaml
  3. hermes config check
```

## Error Handling Approach

- All scripts: `set -euo pipefail` + `trap cleanup EXIT`
- Cleanup trap: removes temp files, restores partial state on failure
- Port conflict (exit 3): `ss -tlnp | grep :20128` → identify conflicting process
- Dependency missing (exit 2): clear message with install command
- Config error (exit 4): backup state preserved, rollback instructions printed
- Test failure (exit 5): named part + suggestion (pin tool-capable model, check egress)
- Streaming timeout: configurable via `--timeout` flag, default 15s
- All error messages follow pattern: `ERROR: <what failed> — <why> — <fix>`

## README Structure

```markdown
# Hermes Agent ↔ OmniRoute Lab

## Prerequisites
- Node ≥ 22.22.2, Hermes v0.20.0, Docker (optional)
- Port 20128 free, egress to free providers

## Quickstart
1. ./scripts/setup.sh
2. ./scripts/configure-hermes.sh
3. ./scripts/smoke-test.sh

## Topology
Hermes → localhost:20128/v1 → OmniRoute → 291 providers

## Configuration
- Example config: config/hermes-omnirouter.example.yaml
- Isolated mode: --isolated flag
- Model pinning: ≥128k recommended

## Docker Alternative
docker compose -f docker-compose.omniroute.yml up -d

## Troubleshooting
- Port in use: see EDGE_CASES.md
- 64k context error: pin ≥128k model
- 401 unauthorized: keyless default, see auth section

## Teardown
- npm: npm uninstall -g omniroute
- Docker: docker compose down -v
- Config: restore from .bak.* or delete ~/.hermes changes
```

## EDGE_CASES.md Content

| Edge Case | Symptom | Cause | Mitigation |
|-----------|---------|-------|------------|
| 64k context minimum | Hermes refuses to start | `auto` routes to model with < 64k context | Pin ≥128k model in config |
| Key-auth 401 | Requests fail with 401 | Gateway requires API key | Set `api_key` via `hermes config set`, store in `.env` |
| Model naming drift | Model not found error | OmniRoute catalog updates model IDs | Pin catalog IDs, check `GET /v1/models` |
| Streaming timeout | SSE stalls, no `[DONE]` | Upstream provider slow/stalled | Increase `--timeout`, check `providers.<id>.request_timeout_seconds` |
| Auxiliary routing | Compression fails | Routed model lacks context for summarizer | Override `auxiliary.compression.provider` to pin larger model |
| Port conflict | Setup fails on port 20128 | Another process uses the port | Kill conflicting process or set `OMNIROUTE_PORT` |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary beyond lab scripts. The lab scripts are self-contained, non-adversarial tooling with no VCS automation or subprocess delegation to untrusted inputs.

## Migration / Rollout

No migration required — greenfield lab. All changes are repo-local. Deleting the repo + documented teardown reverts the box.

## Open Questions

- [ ] Confirm3.8.50 availability — scripts pin3.8.49 (actual latest); if3.8.50 ships before apply, update the pin
- [ ] Hermes `config.yaml` schema: verify `context_length` field is accepted (not all providers support it)
- [ ] Auxiliary routing: does `auxiliary.*.provider` override work in Hermes v0.20.0, or is it `auxiliary.*.base_url`?
