# Proposal: Hermes Agent ↔ OmniRoute Integration Lab

## Intent

Prove Hermes Agent (v0.20.0) runs through OmniRoute's OpenAI-compatible gateway (`localhost:20128/v1`, keyless, `auto`). Ship reproducible setup scripts, example configs, smoke tests, and docs — without breaking the box's existing `~/.hermes` OpenRouter config.

## Scope

### In Scope
- `scripts/setup.sh` — install/boot OmniRoute (npm default, Compose alternative), health check
- `scripts/configure-hermes.sh` — backup `~/.hermes/config.yaml`, write `model:` block, verify via `hermes config check`; `HERMES_HOME` isolation option
- `scripts/smoke-test.sh` — keyless `auto` completion, SSE streaming, tool-call, real `hermes chat -p` turn
- `config/hermes-omnirouter.example.yaml` — annotated model block + auxiliary notes
- `.env.example` + `docker-compose.omniroute.yml` — pinned v3.8.50, ports 20128/20129
- `docs/EDGE_CASES.md` — 64k context, auth, naming, streaming/timeouts, auxiliary routing
- `README.md` — prerequisites, quickstart, topology, troubleshooting

### Out of Scope
- Hermes inside Docker; dashboard/key management flows; gateway benchmarks

## Capabilities

> Contract with sdd-spec. `openspec/specs/` is empty — all capabilities are new.

### New Capabilities
- `omniroute-gateway-setup`: install/boot OmniRoute (npm or Compose), health check
- `hermes-custom-endpoint-config`: wire Hermes custom endpoint with backup/rollback safety
- `integration-smoke-tests`: non-streaming, streaming, tool-calling, Hermes end-to-end
- `lab-documentation`: README + edge-case/troubleshooting docs

### Modified Capabilities
None — greenfield lab.

## Approach

Exploration Approach 1 (bare-metal npm + Hermes config scripts); Compose as documented alternative. Default model: pinned ≥128k catalog ID; `auto` demo-only. All steps reversible (config backups, npm/compose teardown).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `README.md` | New | Quickstart, topology, troubleshooting |
| `scripts/*.sh` | New | setup, configure-hermes, smoke-test |
| `config/hermes-omnirouter.example.yaml` | New | Annotated model block |
| `.env.example`, `docker-compose.omniroute.yml` | New | Env template, pinned gateway |
| `docs/EDGE_CASES.md` | New | Edge cases + mitigations |
| `~/.hermes/config.yaml` | Modified | Via script, backup first |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `auto` lands on small-context model → Hermes refuses start (64k min) | High | Pin ≥128k default; document `context_length` |
| Tool-calling unsupported on free routed models | Med | Dedicated smoke test |
| Catalog/model drift | Med | Pin versions (3.8.50 / v0.20.0) |
| Key-auth → 401 | Low | Keep `api_key: ""`; document key path |
| Mutating real `~/.hermes` | Med | Backup before write; `HERMES_HOME` isolation |

## Rollback Plan

- Hermes: restore `config.yaml.bak.*`; drop `HERMES_HOME` override if used
- OmniRoute: `npm uninstall -g omniroute` or `docker compose down -v`
- Lab: all artifacts live in the repo — deleting the folder reverts the box

## Dependencies

- Node ≥ 22.22.2 (box: 22.23.2 ✓); Docker optional
- OmniRoute v3.8.50; Hermes v0.20.0 (installed)
- Port 20128 free; egress to free providers

## Success Criteria

- [ ] `setup.sh` boots OmniRoute; keyless `/v1/models` answers
- [ ] `configure-hermes.sh` backs up, rewrites, `hermes config check` passes
- [ ] `smoke-test.sh` all parts pass + `hermes chat -p` returns a real answer
- [ ] README reproduces the flow on a clean machine

## Proposal Question Round

Non-interactive run; assumptions for user review: pinned ≥128k default model (not `auto`); `HERMES_HOME` isolation vs in-place edit; npm-global OmniRoute as default install. Confirm or override before specs.
