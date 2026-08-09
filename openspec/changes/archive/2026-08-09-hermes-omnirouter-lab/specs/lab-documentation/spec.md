# Lab Documentation Specification

## Purpose

README and edge-case docs that let a clean machine reproduce the lab: prerequisites, topology, quickstart, example config, troubleshooting, and known edge cases with mitigations.

## Acceptance Criteria

- A clean machine with Node >= 22.22.2 and Hermes v0.20.0 can follow the README to a working `hermes chat -p` answer without undocumented steps (zero-config path).
- `docs/EDGE_CASES.md` covers 64k context, auth states, model naming, streaming/timeouts, auxiliary routing, and `HERMES_HOME` isolation.

## Requirements

### Requirement: README quickstart

The README MUST document prerequisites (Node version, Hermes install, Docker optional), a topology description (Hermes → localhost:20128/v1 → OmniRoute → 291 providers), the quickstart flow (setup → configure → smoke), and troubleshooting.

#### Scenario: Clean-machine reproduction

- GIVEN a clean machine meeting prerequisites
- WHEN the README quickstart commands run in order
- THEN setup, configure, and smoke-test succeed without undocumented steps

#### Scenario: Failure points mapped

- GIVEN a step fails during quickstart
- WHEN the operator checks troubleshooting
- THEN the README maps the symptom to a mitigation and a pointer to EDGE_CASES.md

### Requirement: Edge cases documentation

`docs/EDGE_CASES.md` MUST document each known edge case with symptom, cause, and mitigation: 64k context minimum, key-auth 401, model naming drift (pin catalog IDs), streaming timeouts (SSE stalls, `request_timeout_seconds`), auxiliary routing (compression summarizer context), and `HERMES_HOME` isolation.

#### Scenario: Operator hits a documented edge case

- GIVEN the operator follows quickstart and `auto` routes to a small model
- WHEN Hermes refuses to start
- THEN EDGE_CASES.md explains the 64k minimum and the fix (pin >= 128k)

### Requirement: Example configuration

The repo MUST ship `config/hermes-omnirouter.example.yaml` with an annotated `model:` block (provider, base_url, api_key, context_length) plus auxiliary notes.

#### Scenario: Copy-paste config

- GIVEN a reader wants the stable non-`auto` setup
- WHEN they copy the annotated model block into Hermes config
- THEN it passes `hermes config check` with a pinned >= 128k model

### Requirement: Non-functional — reproducibility

All version references (OmniRoute 3.8.49, Hermes v0.20.0, image tags) MUST be pinned in docs and scripts. The default path MUST be keyless zero-config (no API keys required).

#### Scenario: Version audit

- GIVEN a reviewer reads README, scripts, and compose file
- WHEN they collect every version reference
- THEN every reference matches the pinned versions from this spec

### Requirement: Non-functional — documentation quality

Docs MUST be concise and actionable: copy-pasteable commands, errors mapped to mitigations, no dead references. All lab artifacts MUST live in the repo so deleting the folder reverts the box.

#### Scenario: Reversibility claim

- GIVEN a completed lab
- WHEN the operator deletes the repo and runs documented teardown
- THEN no lab-created files remain outside the repo
