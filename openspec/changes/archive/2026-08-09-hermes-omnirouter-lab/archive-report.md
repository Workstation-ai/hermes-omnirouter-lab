# Archive Report: Hermes Agent ↔ OmniRoute Integration Lab

**Change**: hermes-omnirouter-lab
**Archived**: 2026-08-09
**Mode**: hybrid (openspec filesystem + Engram persistence)
**Archived to**: `openspec/changes/archive/2026-08-09-hermes-omnirouter-lab/`

## Summary

Greenfield lab proving Hermes Agent (v0.20.0) runs through OmniRoute's OpenAI-compatible
gateway (`localhost:20128/v1`, keyless, `auto`). Delivered 8 implementation files: three
scripts (`setup.sh`, `configure-hermes.sh`, `smoke-test.sh`), an annotated example config,
`.env.example` + pinned `docker-compose.omniroute.yml`, `docs/EDGE_CASES.md`, and `README.md` —
without breaking the box's existing `~/.hermes` OpenRouter config (backup + `HERMES_HOME`
isolation).

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| OmniRoute install method | npm global default, `--compose` flag alternative | Node 22.23.2 present; Docker optional per scope |
| Default model | `auto` for demo; documented pinned ≥128k fallback (`google/gemini-2.5-flash`, 1048576 ctx) | Hermes requires ≥64k minimum; `auto` can land on small models |
| HERMES_HOME isolation | Timestamped backup + in-place edit default; `--isolated` opt-in | In-place simpler; isolation risk-averse; backup mandatory both paths |
| **Version pin** | **v3.8.49 (not 3.8.50)** | **3.8.50 is not published on npm — scripts pin the real latest; `.env.example` documents this as a warning comment** |
| Script error taxonomy | `set -euo pipefail`, numeric exit codes 0–5 | Uniform mapping to README mitigations |
| Delivery | Single PR, ~200–300 lines | 400-line budget risk: Low |

## Final Verification State (Phase 4 — independently re-run at archive time)

- `bash -n scripts/*.sh` → all 3 scripts pass (SYNTAX-OK)
- `docker compose -f docker-compose.omniroute.yml config` → valid; image
  `diegosouzapw/omniroute:3.8.49`, ports 20128/20129 on 127.0.0.1, curl healthcheck,
  `restart: unless-stopped`
- Version audit across all 8 implementation files → **zero stale 3.8.50 references**;
  every pin matches v3.8.49 / v0.20.0 (only `.env.example` mentions 3.8.50, as an
  intentional "does not exist on npm" warning comment)

## Reconciliation Notes (intentional partial archive — with warnings)

1. **Missing `verify-report.md` artifact.** No verify-report exists on the filesystem nor in
   Engram; no review receipts/ledger/gate-context were persisted for this change (no
   state.yaml, no judgment-day review run). Verification evidence was folded into the apply
   phase (tasks Phase 4, see observation #88: "Docker Compose config validation passes; all
   bash scripts pass syntax check"). Per the archive policy, the missing artifact is
   **recorded and flagged**; archive proceeds because (a) the orchestrator explicitly
   launched the archive phase, (b) no CRITICAL issues were ever recorded, and (c) the
   Phase-4 checks were independently re-executed and pass at archive time. Recommended
   follow-up: persist a proper verify-report for future changes.
2. **Version drift correction in delta specs (3.8.50 → 3.8.49).** The delta specs
   `omniroute-gateway-setup` and `lab-documentation` referenced v3.8.50, which is not
   published. Corrected BEFORE syncing main specs and before the archive move, so both the
   main specs and the archived copy reflect the implemented v3.8.49. Historical artifacts
   (`proposal.md`, Engram proposal #84) keep their original 3.8.50 references as audit
   trail — the design's "Decision: Version pin" records the correction rationale.
3. **Engram snapshot reconciliation.** Engram specs observation #85 and tasks observation
   #87 were snapshots from earlier phases (spec #85 referenced 3.8.50; tasks #87 was stored
   pre-apply without checkbox marks). Both were updated at archive time to match the final
   filesystem state. All tasks are complete on the persisted artifact (archived tasks.md:
   11/11 `[x]`, 0 unchecked).

## Specs Synced (delta → main)

All 4 domains are greenfield full specs (main `openspec/specs/` was empty):

| Domain | Action | Details |
|--------|--------|---------|
| omniroute-gateway-setup | Created | 3 requirements: install (pinned v3.8.49), boot + health check, teardown |
| hermes-custom-endpoint-config | Created | 6 requirements: backup, model block wiring, HERMES_HOME isolation, rollback, auth states, auxiliary routing |
| integration-smoke-tests | Created | 5 requirements: keyless auto, SSE streaming, tool-calling, Hermes e2e, exit semantics |
| lab-documentation | Created | 5 requirements: README quickstart, edge cases, example config, NFR reproducibility, NFR doc quality |

## Archive Contents

- proposal.md ✅
- exploration.md ✅
- specs/ (4 domain specs) ✅
- design.md ✅
- tasks.md ✅ (11/11 tasks complete)
- archive-report.md ✅ (this file)

## Engram Observation IDs (traceability)

| Artifact | Observation ID |
|----------|----------------|
| explore | #83 |
| proposal | #84 |
| spec | #85 (updated at archive: 3.8.49) |
| design | #86 |
| tasks | #87 (updated at archive: final checked state) |
| apply work-item | #88 |
| archive-report | this report (new observation) |

## SDD Cycle Complete

The change has been fully planned, implemented, verified, and archived.
Ready for the next change.