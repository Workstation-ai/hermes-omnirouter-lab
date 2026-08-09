# Hermes Custom Endpoint Configuration Specification

## Purpose

Wire Hermes Agent (v0.20.0) to the OmniRoute gateway through its OpenAI-compatible custom endpoint (`provider: custom`, `base_url: http://localhost:20128/v1`) without risking the box owner's existing `~/.hermes` OpenRouter config — backup first, `HERMES_HOME` isolation option, verify, rollback.

## Acceptance Criteria

- `scripts/configure-hermes.sh` backs up `~/.hermes/config.yaml`, writes the `model:` block, and `hermes config check` passes afterward.
- With `HERMES_HOME` isolation, the real `~/.hermes` is never modified.

## Requirements

### Requirement: Backup before mutation

The configure script MUST create a timestamped backup of `~/.hermes/config.yaml` (e.g. `config.yaml.bak.<ts>`) before any write and MUST abort if the backup cannot be created.

#### Scenario: Backup created

- GIVEN an existing `~/.hermes/config.yaml`
- WHEN configure runs
- THEN a timestamped `.bak.<ts>` copy exists before any modification

#### Scenario: Backup write fails

- GIVEN the config directory is not writable
- WHEN configure runs
- THEN it aborts with a clear message and changes nothing

### Requirement: Model block wiring

The script MUST write a `model:` block with `provider: custom`, `base_url: http://localhost:20128/v1`, empty `api_key`, and a pinned model with context >= 128k plus documented `context_length`, per `config/hermes-omnirouter.example.yaml`. The >= 128k pin MUST protect against Hermes' 64k minimum context requirement when `auto` routes to a small model.

#### Scenario: Happy path wiring

- GIVEN Hermes v0.20.0 installed and OmniRoute healthy
- WHEN configure runs
- THEN config.yaml contains the custom endpoint model block and `hermes config check` passes

#### Scenario: auto lands on a small-context model

- GIVEN `model.default: auto` routes to a model with < 64k context
- WHEN `hermes chat` starts
- THEN Hermes refuses to start with a context error
- AND the user re-pins the >= 128k default from the example config

### Requirement: HERMES_HOME isolation

The script MUST support an isolated Hermes home (e.g. `HERMES_HOME=<repo>/.hermes-lab`) so the real `~/.hermes` is never touched. In-place edit with backup MUST remain the default.

#### Scenario: Isolated run

- GIVEN the user opts into isolation
- WHEN configure runs
- THEN all config writes land under the isolated home
- AND `~/.hermes/config.yaml` is byte-identical before and after

### Requirement: Rollback

The script MUST document rollback: restore the latest backup and drop the `HERMES_HOME` override if used.

#### Scenario: Restore

- GIVEN a configured Hermes and an existing backup
- WHEN rollback runs
- THEN config.yaml is restored from backup and `hermes config check` passes

### Requirement: Auth state handling

The zero-config path MUST use `api_key: ""` (keyless). When the gateway requires keys, the script MUST document setting `model.api_key` via `hermes config set`, storing the secret in `.env`, never in `config.yaml`.

#### Scenario: Keyless success vs key-auth 401

- GIVEN keyless OmniRoute
- WHEN Hermes sends a chat request
- THEN it succeeds with `api_key: ""`
- AND when keys are required, requests fail 401 and the documented key path resolves it

### Requirement: Auxiliary task routing

The script SHOULD document that auxiliary tasks (vision, compression summarizer, MoA) default to the main custom endpoint via `auxiliary.*.provider: auto`, and MUST note the per-task override (`auxiliary.<task>.provider`) because the compression summarizer needs context >= main model.

#### Scenario: Compression through the gateway

- GIVEN a long session triggering compression
- WHEN the compression summarizer runs
- THEN it routes through OmniRoute and the EDGE_CASES doc explains the override path if the routed model cannot serve it
