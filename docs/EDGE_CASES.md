# Edge Cases — Hermes + OmniRoute Integration

Known edge cases, their symptoms, causes, and mitigations.

| # | Edge Case | Symptom | Cause | Mitigation |
|---|-----------|---------|-------|------------|
| 1 | **64k context minimum** | Hermes refuses to start; error mentions context size | `model: auto` routes to a model with < 64k context window | Pin a >= 128k model in `config.yaml`: `google/gemini-2.5-flash` (1M), `meta-llama/llama-3.3-70b-versatile` (128k), or `openai/gpt-4o-mini` (128k). Uncomment `context_length` in the example config. |
| 2 | **Key-auth 401** | Requests return HTTP 401 Unauthorized | Gateway or provider requires an API key; default keyless (`api_key: ""`) is insufficient | Set `model.api_key` via `hermes config set`, or store the key in `.env` and reference it. Never commit keys to `config.yaml`. |
| 3 | **Model naming drift** | "Model not found" error after OmniRoute update | OmniRoute catalog renames or removes a model ID; `auto` routes to stale ID | Pin specific catalog IDs instead of `auto`. Check available models with `curl http://localhost:20128/v1/models`. |
| 4 | **Streaming timeout** | SSE stalls mid-stream; no `[DONE]` terminator arrives | Upstream provider slow, rate-limited, or unreachable | Increase `--timeout` on the smoke test. Check `providers.<id>.request_timeout_seconds` in OmniRoute config. Verify egress to upstream providers. |
| 5 | **Auxiliary routing** | Compression summarizer fails on long sessions | Routed model lacks sufficient context for the summarizer | Override `auxiliary.compression.provider` or `auxiliary.compression.model` in Hermes config to pin a larger-context model (>= main model context). See `config/hermes-omnirouter.example.yaml`. |
| 6 | **Port conflict** | `setup.sh` fails; port 20128 already in use | Another process occupies the gateway port | Kill the conflicting process (`ss -tlnp | grep :20128`) or set `OMNIROUTE_PORT` in `.env` to use a different port. |

## Troubleshooting Flow

```
Request fails?
  ├─ 401 → see #2 (auth state)
  ├─ Context error → see #1 (64k minimum)
  ├─ Model not found → see #3 (naming drift)
  ├─ Streaming stalls → see #4 (timeout)
  ├─ Compression fails → see #5 (auxiliary routing)
  └─ Setup won't start → see #6 (port conflict)
```
