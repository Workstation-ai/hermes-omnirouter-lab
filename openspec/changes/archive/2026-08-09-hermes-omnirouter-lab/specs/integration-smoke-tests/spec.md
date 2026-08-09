# Integration Smoke Tests Specification

## Purpose

`scripts/smoke-test.sh` proves the integration works: keyless `auto` completion (non-streaming), SSE streaming, a tool-calling request, and a real Hermes turn via `hermes chat -p`.

## Acceptance Criteria

- All parts pass on a healthy setup.
- Each part has distinct, parseable output; a failed part yields a non-zero exit naming the failing part.

## Requirements

### Requirement: Keyless auto completion (non-streaming)

The smoke test MUST POST a non-streaming chat completion with `"model": "auto"` and no auth header to `http://localhost:20128/v1/chat/completions` and MUST assert HTTP 200 with non-empty content.

#### Scenario: Happy path

- GIVEN OmniRoute healthy and egress available
- WHEN the non-streaming request runs
- THEN HTTP 200 with non-empty `choices[0].message.content`

### Requirement: SSE streaming

The smoke test MUST issue a streaming request and MUST assert SSE `data:` chunks arrive and the stream terminates with `[DONE]` within the timeout.

#### Scenario: Stream completes

- GIVEN a streaming request
- WHEN the response is read
- THEN at least one `data:` chunk arrives and `[DONE]` terminates the stream

#### Scenario: Stream stalls

- GIVEN an upstream provider stalls mid-stream
- WHEN no chunk arrives within the timeout
- THEN the test fails with a streaming timeout message and points to `providers.<id>.request_timeout_seconds`

### Requirement: Tool-calling verification

The smoke test MUST send a request with a `tools` array and MUST report whether the routed model returned `tool_calls` — pass when present, explicit FAIL when the model lacks tool support (never hang).

#### Scenario: Model supports tool calls

- GIVEN a routed model that supports tool calling
- WHEN a tool-enabled request runs
- THEN `tool_calls` is present in the response

#### Scenario: Model lacks tool support

- GIVEN the routed free model does not support tool calling
- WHEN the tool request runs
- THEN the test exits non-zero with a named tool-support failure
- AND the user is directed to pin a tool-capable catalog model

### Requirement: Hermes end-to-end turn

The smoke test MUST run `hermes chat -p "<prompt>"` against the custom provider and MUST assert a real, non-empty answer.

#### Scenario: Hermes answers

- GIVEN Hermes configured for the custom endpoint
- WHEN `hermes chat -p "hello"` runs
- THEN a non-empty response is printed and the part passes

#### Scenario: Hermes refuses to start (64k context)

- GIVEN the pinned model has < 64k context
- WHEN the Hermes turn starts
- THEN the test fails with the documented context error and points to the >= 128k pin

### Requirement: Exit semantics

The smoke test MUST be fail-fast: each part reports PASS/FAIL by name, a failed part stops the run with non-zero exit, and a final summary lists part results.

#### Scenario: Mixed results

- GIVEN one part fails while earlier parts pass
- WHEN the script finishes
- THEN the summary lists each part with its result
- AND the exit code is non-zero
