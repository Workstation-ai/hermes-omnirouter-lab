# Tasks: Hermes Agent ↔ OmniRoute Integration Lab

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 200–300 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Scripts (setup, configure, smoke) | PR 1 | `bash -n scripts/*.sh` + `scripts/smoke-test.sh --skip-hermes` | N/A — syntax check only; real harness requires OmniRoute installed | scripts/ directory |
| 2 | Config + Docker + Docs | PR 1 | `docker compose -f docker-compose.omniroute.yml config` | N/A — config validation only | config/, .env.example, docker-compose, docs/ |

## Phase 1: Foundation — Config & Docker Artifacts

- [x] 1.1 Create `.env.example` with `OMNIROUTE_PORT=20128`, `OMNIROUTE_VERSION=3.8.49`, `OMNIROUTE_HOST=127.0.0.1`, and commented notes per design spec
- [x] 1.2 Create `docker-compose.omniroute.yml` pinning `diegosouzapw/omniroute:3.8.49`, ports 20128/20129 on 127.0.0.1, healthcheck (`curl -sf http://localhost:20128/v1/models`), `restart: unless-stopped`
- [x] 1.3 Create `config/hermes-omnirouter.example.yaml` with annotated `model:` block (provider: custom, base_url, api_key: "", auto default + pinned ≥128k alternative, context_length comment, auxiliary routing notes)

## Phase 2: Core Scripts

- [x] 2.1 Create `scripts/setup.sh` — `set -euo pipefail`, flags `--compose` / `--health-timeout`, idempotent install (detect existing), Node ≥22.22.2 check (exit 2), port conflict detection (exit 3), health poll GET /v1/models, version drift warning, Compose path with Docker check
- [x] 2.2 Create `scripts/configure-hermes.sh` — `set -euo pipefail`, flags `--isolated` / `--rollback`, timestamped backup before write (exit 4 on failure), write model block (provider: custom, base_url, api_key: ""), `hermes config check` verification, rollback restores latest .bak.*; isolated path uses HERMES_HOME=<repo>/.hermes-lab, never touches ~/.hermes
- [x] 2.3 Create `scripts/smoke-test.sh` — `set -euo pipefail`, flags `--isolated` / `--skip-hermes`, 4 parts fail-fast: (1) non-streaming auto POST assert 200+content, (2) streaming SSE assert chunks+[DONE] with timeout, (3) tool-calling assert tool_calls or explicit FAIL, (4) hermes chat -p assert non-empty; exit 0 all pass, exit 5 any fail, summary output

## Phase 3: Documentation

- [x] 3.1 Create `docs/EDGE_CASES.md` — table of 6 edge cases (64k context, key-auth 401, model naming drift, streaming timeout, auxiliary routing, port conflict) with symptom/cause/mitigation per design spec
- [x] 3.2 Create `README.md` — prerequisites (Node ≥22.22.2, Hermes v0.20.0, Docker optional), topology diagram (Hermes → localhost:20128/v1 → OmniRoute → providers), quickstart (setup → configure → smoke), configuration section, Docker alternative, troubleshooting mapped to EDGE_CASES.md, teardown instructions

## Phase 4: Verification

- [x] 4.1 Run `bash -n scripts/*.sh` to verify all scripts parse without syntax errors
- [x] 4.2 Run `docker compose -f docker-compose.omniroute.yml config` to validate compose file syntax
- [x] 4.3 Verify every version reference across all 8 files matches v3.8.49 / v0.20.0 (no stale 3.8.50 references)
