# Hermes Agent ↔ OmniRoute Integration Lab

Lab that wires Hermes Agent (Nous Research CLI) to OmniRoute as the backend AI provider, giving Hermes access to 291+ providers through a single OpenAI-compatible endpoint.

## Prerequisites

- **Node.js >= 22.22.2** — `node -v` to check
- **Hermes Agent v0.20.0** — `hermes --version` to check
- **Docker** (optional) — only needed if using the Compose path
- **Port 20128 free** — `ss -tlnp | grep :20128` to check
- **Egress access** — OmniRoute routes to free providers; ensure outbound connectivity

## Topology

```
Hermes Agent
    ↓
localhost:20128/v1 (OpenAI-compatible)
    ↓
OmniRoute Gateway (v3.8.49)
    ↓
291+ AI providers (auto-selected)
```

Hermes sends requests to the local OmniRoute endpoint. OmniRoute selects the best provider per request (with `auto`) or forwards to a pinned provider.

## Quickstart

```bash
# 1. Install and boot OmniRoute
./scripts/setup.sh

# 2. Configure Hermes to use the local gateway
./scripts/configure-hermes.sh

# 3. Verify the integration
./scripts/smoke-test.sh
```

For a full end-to-end test:

```bash
hermes chat -p "Hello, which provider are you?"
```

## Configuration

### Example Config

`config/hermes-omnirouter.example.yaml` contains an annotated `model:` block. Key settings:

- `provider: custom` — use OpenAI-compatible endpoint
- `base_url: http://localhost:20128/v1` — local OmniRoute
- `api_key: ""` — keyless (default)
- `default: auto` — dynamic routing (demo); pin `google/gemini-2.5-flash` for stability

### Model Selection

| Model | Context | Use Case |
|-------|---------|----------|
| `auto/best-coding` | varies | **Recommended** — combo model, best provider per request |
| `auto/best-chat` | varies | Combo model, optimized for chat |
| `auto` | varies | Basic auto-routing (may hit broken free tiers) |
| `google/gemini-2.5-flash` | 1M | Production (stable, free) |
| `meta-llama/llama-3.3-70b-versatile` | 128k | Production (stable) |
| `openai/gpt-4o-mini` | 128k | Production (stable) |

Pin >= 128k models to avoid Hermes' 64k context minimum. See [docs/EDGE_CASES.md](docs/EDGE_CASES.md) for details.

### Model Fallback Behavior

OmniRoute's `auto` models route to different providers per request. Some free tier providers (especially `oc/` prefix models like `oc/hy3-free`, `oc/north-mini-code-free`) frequently return 401 errors due to auth issues or exhausted quotas.

**Tested results:**

| Model | Behavior | Result |
|-------|----------|--------|
| `auto/chat` | Routes to basic free tiers | ❌ Frequent 401 errors (12+ failures in logs) |
| `auto/best-coding` | Uses combo models, selects best provider | ✅ Stable, no 401 errors |

The `best-*` and `pro-*` combo models are more reliable because they evaluate multiple providers and pick the best available one, rather than defaulting to a single free tier.

**Recommendation:** Use `auto/best-coding` or `auto/best-chat` instead of plain `auto` for production use.

### Isolated Mode

Run without touching `~/.hermes`:

```bash
./scripts/configure-hermes.sh --isolated
# Hermes config lives at repo/.hermes-lab/ — real ~/.hermes untouched

# Smoke test with isolated config
./scripts/smoke-test.sh --isolated
```

### Rollback

Restore your original Hermes config:

```bash
./scripts/configure-hermes.sh --rollback
```

## Docker Alternative

Skip the npm install and use Docker Compose:

```bash
# Start OmniRoute in Docker
docker compose -f docker-compose.omniroute.yml up -d

# Then configure Hermes normally
./scripts/configure-hermes.sh

# Or use --compose flag on setup
./scripts/setup.sh --compose
```

The Docker Compose file pins `diegosouzapw/omniroute:3.8.49` and uses `network_mode: host` so the container can reach free-tier providers directly (the default bridge network often blocks outbound HTTPS in restricted environments).

### Dashboard

OmniRoute ships a Next.js dashboard with live provider health, token budgets, and routing analytics. Access it at:

```
http://localhost:20128/dashboard
```

The dashboard URL is printed automatically by `./scripts/setup.sh` and `./scripts/configure-hermes.sh`.

## Scripts Reference

| Script | Purpose | Key Flags |
|--------|---------|-----------|
| `scripts/setup.sh` | Install + boot OmniRoute | `--compose`, `--health-timeout SECS` |
| `scripts/configure-hermes.sh` | Wire Hermes to local gateway | `--isolated`, `--rollback` |
| `scripts/smoke-test.sh` | 4-part integration test | `--isolated`, `--skip-hermes` |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Dependency missing (Node, Docker) |
| 3 | Port conflict |
| 4 | Config error (backup failed, verification failed) |
| 5 | Smoke test failure |

## Troubleshooting

| Symptom | Fix | Details |
|---------|-----|---------|
| Port 20128 in use | Kill conflicting process or change `OMNIROUTE_PORT` | `ss -tlnp | grep :20128` |
| Hermes context error | Pin >= 128k model | See `config/hermes-omnirouter.example.yaml` |
| 401 Unauthorized | Set API key or switch model | `hermes config set model.api_key YOUR_KEY` or use `auto/best-coding` |
| Model not found | Pin a specific model | Check `curl localhost:20128/v1/models` |
| Streaming stalls | Increase timeout, check egress | See [docs/EDGE_CASES.md](docs/EDGE_CASES.md) |
| 401 from free tier models | Switch to `auto/best-coding` | Plain `auto` routes to broken `oc/*` free tiers; `best-*` combo models are more reliable |
| ConnectTimeoutError to providers | Use `network_mode: host` in Docker Compose | The default bridge network blocks outbound HTTPS in many environments; the compose file already uses `network_mode: host` |
| Dashboard unreachable | Open `http://localhost:20128/dashboard` | Requires the container to be running; the dashboard is served via the main API port

## Teardown

```bash
# Remove OmniRoute (npm path)
npm uninstall -g omniroute
rm -rf ~/.omniroute

# Remove OmniRoute (Docker path)
docker compose -f docker-compose.omniroute.yml down -v

# Restore Hermes config
./scripts/configure-hermes.sh --rollback

# Remove lab artifacts
rm -rf scripts/ config/ docs/ .env docker-compose.omniroute.yml
```

Deleting the repo directory after teardown leaves no lab-created files on the box.
