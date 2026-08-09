# Exploration: Hermes Agent ↔ OmniRoute Lab

**Date**: 2026-08-08
**Change**: `hermes-omnirouter-lab` (project-level)
**Mode**: hybrid (Engram + openspec)

## Current State

Fresh empty repo at `/tmp/hermes-omnirouter-lab` (SDD initialized only). No code, no scripts, no docs yet.

Two external systems are the subjects of the lab:

**Hermes Agent** (Nous Research, MIT, v0.20.0 installed on this box at `~/.hermes/`):
- Config home: `~/.hermes/` — `config.yaml` (non-secrets), `.env` (secrets), `auth.json` (OAuth), `SOUL.md`, `memories/`, `skills/`, `sessions/`
- Precedence: CLI args > `config.yaml` > `.env` > built-in defaults
- **Model config** (single source of truth is `config.yaml`, not env vars — `LLM_MODEL` is removed; `OPENAI_BASE_URL` is honored only for the legacy `openai-api` provider):
  ```yaml
  model:
    default: <model-id>        # or `model:` alias key
    provider: custom           # "custom" = any OpenAI-compatible endpoint
    base_url: http://localhost:20128/v1
    api_key: ""                # empty = keyless (works with OmniRoute auto combo)
    context_length: 128000     # optional, see edge case
  ```
- Interactive path: `hermes model` wizard → "Custom endpoint (self-hosted / VLLM / etc.)" → enter base URL → (optional) key → pick/verify model via `/v1/models`. Verified flow documented by Ollama integration ("Verified endpoint via http://127.0.0.1:11434/v1/models").
- CLI: `hermes config set/get/unset/edit/check`, `hermes chat --provider custom --model <id>`, in-session `/model custom` (bare = auto-detect via `/v1/models`), `/model custom:<model>`, `/model custom:<named>:<model>` triple syntax for named custom providers
- `config.yaml` supports `${VAR}` env substitution; secrets go to `.env` via `hermes config set <KEY> <val>`
- **Hard requirement: main model must support ≥64,000 tokens of context** — Hermes rejects smaller windows at startup (system prompt + tool schemas need the room)
- Auxiliary tasks (vision, compression summarizer, MoA, web extraction) default to `auxiliary.*.provider: "auto"` → routed to the main chat model (i.e., also through the custom endpoint unless overridden)
- Streaming default `true`; provider-wide timeout via `providers.<id>.request_timeout_seconds` (default 1800s from `HERMES_API_TIMEOUT`)
- Box state today: `provider: auto`, `base_url: https://openrouter.ai/api/v1`, `model: anthropic/claude-opus-4.6`, **no** `OPENROUTER_API_KEY` in `.env` — i.e., the existing install is not currently usable and is safe to repoint or isolate (backup `config.yaml.bak.20260805_121116` exists from a prior edit)

**OmniRoute** (diegosouzapw/OmniRoute, MIT, v3.8.50, 43k+ stars; npm `omniroute`, Docker Hub `diegosouzapw/omniroute`):
- OpenAI-compatible gateway: one endpoint `http://localhost:20128/v1`, 291 providers / 500+ models, 19 routing strategies, 4-tier auto-fallback, quota-aware
- **Zero-config**: fresh install answers keyless with `"model": "auto"` (routes to pre-wired free providers OpenCode Free + Felo). Optional API keys `sk-...` minted at `/dashboard/api-manager` for scoping/gating; standard `Authorization: Bearer sk-...`
- Endpoint surface: `/v1/chat/completions` (OpenAI), `/v1/responses` (Codex/agentic), `/v1/completions`, `/v1/embeddings`, `/v1/images/generations`, `/v1/audio/*`; Anthropic surface at the root (no `/v1`); Gemini surface at `/v1beta`
- Model naming: `auto` (combo router) or provider-prefixed catalog IDs (`oc/...`, `felo/...`, `glm/glm-5.2`, `qwen/qwen3.8-max-preview`…)
- Install: `npm install -g omniroute` (needs Node 22.22.2+ or 24.x — box has v22.23.2 ✓), boots on 20128; `omniroute setup` wizard, `omniroute doctor`, `omniroute health`; Docker Compose with profiles (`base`/`web`/`cli`/`host`/`cliproxyapi`/`memory`/`bifrost`), ports 20128 (API/dashboard), 20129 (API_PORT), 20132 (live WS), 6379 redis (loopback), 6333 Qdrant (opt-in)
- **Hermes is an officially listed compatible CLI**: catalog id `hermes-agent` in the CLI Agents catalog with `baseUrlSupport: "full"`, `configType: env/custom`. There is NO `setup-hermes` command (unlike codex/claude/opencode/…) — Hermes is wired manually via its own `hermes model` wizard or `config.yaml` (note: a separate `hermes` entry in the CLI Code's catalog is `baseUrlSupport: none` and is not shown in the dashboard)
- Not installed/running on this box today (port 20128 closed)

## Affected Areas (planned lab layout — nothing exists yet)

- `README.md` — purpose, prerequisites, quickstart, topology diagram, troubleshooting
- `scripts/setup.sh` — install OmniRoute (npm global or compose), wait for health, smoke-test `/v1/models` + a `model: auto` completion
- `scripts/configure-hermes.sh` — backup `~/.hermes/config.yaml`, write `model:` block (`provider: custom`, `base_url: http://localhost:20128/v1`) or drive `hermes model` equivalent via `hermes config set`
- `scripts/smoke-test.sh` — non-streaming, streaming (SSE), and tool-call request through OmniRoute; verify Hermes answers (`hermes chat`/`-p "hello"`)
- `config/hermes-omnirouter.example.yaml` — annotated `model:` section + auxiliary notes
- `.env.example` + `docker-compose.omniroute.yml` — pinned OmniRoute version, profiles, ports, DATA_DIR
- `docs/EDGE_CASES.md` — auth, model naming, 64k context, streaming, timeouts, auxiliary routing

## Approaches

1. **Bare-metal npm + Hermes config scripts** (recommended core)
   - Scripts install `omniroute` globally (Node ✓ on this box), boot server, wire Hermes `model:` block via `hermes config set`, run smoke tests; all reversible (backup before edit; OmniRoute lives in npm global + `~/.omniroute` data dir)
   - Pros: matches the box exactly; fastest path to a working demo; no Docker download; uses Hermes' own supported custom-endpoint flow; full dashboard + CLI available
   - Cons: pollutes the user's real `~/.hermes` (mitigate with `HERMES_HOME` isolation or profile); not hermetic across machines
   - Effort: Low

2. **Docker Compose for OmniRoute + host Hermes**
   - Reproduce the gateway via `diegosouzapw/omniroute` image + pinned tag, profiles, `.env`; Hermes stays on host pointed at `localhost:20128`
   - Pros: reproducible, isolated, cleans up cleanly; matches "lab" framing
   - Cons: image is large (web profile ships Chromium), needs `.env` copy + data volume; adds Redis/port orchestration for full compose; slower first run
   - Effort: Medium

3. **Hermes inside Docker too** (full containerization)
   - Hermes has an official Docker path (`docs/user-guide/docker`) — run both services in compose
   - Pros: fully hermetic lab, zero host mutation
   - Cons: Hermes in Docker is heavier (its state, skills, terminals), harder to demo interactively on this box, more moving parts than the experiment needs
   - Effort: High

## Recommendation

**Approach 1 + optional Approach 2**: ship scripts + example configs that install OmniRoute via npm (default) with a documented `docker-compose.omniroute.yml` alternative. Wire Hermes via `hermes config set model.provider custom` / `model.base_url` after backing up `config.yaml`, using `HERMES_HOME` isolation (or a named profile) so the box owner's existing OpenRouter config is untouched. Default model ID: `auto` for the demo, with a pinned high-context model (e.g. `glm/glm-5.2`-class, 128k+) as the documented stable choice. Prove the loop with a 3-part smoke test: keyless `auto` completion, SSE streaming, and a tool-calling request, then a real `hermes chat -p` turn.

Comparison grounding (for README): Claude Code uses `ANTHROPIC_BASE_URL=http://localhost:20128` (root, no `/v1`) + `ANTHROPIC_AUTH_TOKEN` in `~/.claude/settings.json` or `omniroute launch`; Codex uses `~/.codex/config.yaml` (`model: auto`, `apiKey`, `apiBaseUrl: http://localhost:20128/v1`) or `setup-codex` profiles + `launch-codex`, hitting `/v1/responses`; Cursor is opaque (SQLite) — `setup-cursor` only prints in-app steps; Hermes is the odd one out in a good way: first-class "custom endpoint" wizard + `provider: custom` in `config.yaml`, OpenAI-compatible `/v1/chat/completions`, keyless-capable.

## Risks

- **64k context minimum**: if OmniRoute's `auto` combo lands on a small-context free model, Hermes refuses to start. Mitigate: pin a ≥128k model for `model.default`; document `context_length`.
- **Auxiliary/compression calls** also traverse OmniRoute (provider auto → main model); the compression summarizer must have context ≥ main model. Monitor token burn on free tiers; can be overridden per-task (`auxiliary.compression.provider`/`base_url`).
- **Model naming drift**: OmniRoute catalog is huge and fast-moving (6352 commits, re-audited bi-weekly); `auto`/combo behavior can change. Pin versions (OmniRoute tag + Hermes release) in the lab for reproducibility.
- **Tool-calling compatibility**: Hermes agent loops depend on the routed model's tool-call support. Not every free/cheap model behind OmniRoute supports tool calling well — verify with a dedicated smoke test before documenting "works".
- **Auth state**: OmniRoute is keyless by default but can be configured to require keys (401). If key auth is enabled, `model.api_key` must be set in Hermes config; keep `api_key: ""` documented for the zero-config path.
- **Host mutation**: editing the box's real `~/.hermes/config.yaml` could disrupt existing use. Always back up first; prefer `HERMES_HOME` isolation in the lab scripts.
- **Streaming behavior**: Hermes streams by default; OmniRoute supports SSE, but a proxy/provider hiccup mid-stream should be surfaced in `EDGE_CASES.md` (timeouts: `providers.<id>.request_timeout_seconds`, Hermes default 1800s vs OmniRoute circuit breakers).

## Ready for Proposal

Yes — tell the user: Hermes Agent and OmniRoute are officially compatible (Hermes is in OmniRoute's supported CLI catalog with full base-URL support), the integration is a ~15-line `config.yaml` change on Hermes' side plus `npm i -g omniroute`, and the box is ready (Node 22.23.2 ✓, Hermes v0.20.0 ✓, Docker ✓, OmniRoute not yet installed). Propose the lab as: scripts + example configs + smoke tests + README, defaulting to a pinned high-context model rather than relying on `auto`.
