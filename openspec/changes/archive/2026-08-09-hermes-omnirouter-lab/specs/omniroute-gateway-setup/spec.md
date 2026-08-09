# OmniRoute Gateway Setup Specification

## Purpose

Provide a reproducible script that installs and boots the OmniRoute OpenAI-compatible gateway (v3.8.49) locally — npm global install by default, Docker Compose as a documented alternative — and proves the gateway answers keyless on the expected endpoint.

## Acceptance Criteria

- `scripts/setup.sh` installs OmniRoute v3.8.49 (npm default; `--compose` alternative), waits for health, and confirms keyless `GET /v1/models` answers on `http://localhost:20128/v1`.
- Setup is idempotent and reversible; teardown is documented (`npm uninstall -g omniroute` or `docker compose down -v`).

## Requirements

### Requirement: Install OmniRoute (pinned version)

The setup script MUST install OmniRoute pinned to v3.8.49 via `npm install -g omniroute` after verifying Node >= 22.22.2. The Compose alternative MUST pin the `diegosouzapw/omniroute` image to the same version and map ports 20128/20129.

#### Scenario: Fresh npm install

- GIVEN a machine with Node >= 22.22.2 and no OmniRoute installed
- WHEN `scripts/setup.sh` runs with defaults
- THEN OmniRoute v3.8.49 is installed globally and the script reports success

#### Scenario: Version drift

- GIVEN omniroute v3.9.0 is already installed globally
- WHEN setup runs
- THEN the script SHALL warn on the mismatch and MAY pin/downgrade to v3.8.49 for reproducibility

#### Scenario: Docker missing on Compose path

- GIVEN the user passes `--compose` and Docker is not installed
- WHEN the script runs
- THEN it fails with a clear message pointing to the npm path, not a cryptic docker error

### Requirement: Boot and health check

The setup script MUST start OmniRoute bound to `127.0.0.1:20128` and MUST wait until keyless `GET http://localhost:20128/v1/models` returns 200 before declaring success. A fresh install MUST answer keyless (no API key) — the zero-config path.

#### Scenario: Healthy boot

- GIVEN OmniRoute installed and port 20128 free
- WHEN setup starts the server and polls health
- THEN `/v1/models` returns 200 without an Authorization header
- AND the script prints the endpoint and the next step

#### Scenario: Port already in use

- GIVEN another process listens on 20128
- WHEN setup attempts to boot
- THEN it detects the conflict and either confirms an existing healthy OmniRoute or fails with remediation steps

#### Scenario: Upstream egress blocked

- GIVEN the host cannot reach upstream free providers
- WHEN `model: auto` requests fail after a healthy boot
- THEN the health check still passes for the API surface
- AND the failure is reported as an upstream/egress problem, not an install problem

### Requirement: Teardown / reversibility

The repository MUST document full gateway removal (npm uninstall or `docker compose down -v`) so teardown leaves the box as found.

#### Scenario: npm teardown

- GIVEN OmniRoute was installed via npm
- WHEN the documented teardown runs
- THEN the global package and `~/.omniroute` data are removed and port 20128 is released
