# Headless orchestration duplicate-session race hardening

Date: 2026-09-12  
Router task: `1061ff77-719a-4787-86f7-85f294888256`  
Verdict: **REVIEW — IMPLEMENTED_DEFAULT_PATH_PRESERVED**

## Result

The headless wrapper now admits only one concrete controller session per agent
lane. Ownership is the tuple `(agent_id, session_token, pid, host)`, not the
broad `agent_id`. A second concurrently firing `claude` wrapper sees the live
30-minute lease and exits successfully with the journaled reason
`foreign_live_headless_session`; it cannot renew or release the first session's
lease. The owner renews during the existing ten-minute heartbeat slices and
releases only through its exact tuple.

A fresh `D:/QM/strategy_farm/state/INTERACTIVE_ORCHESTRATOR.flag` also makes a
headless cycle exit before lease acquisition or model spawn. The JSON marker
binds `pid`, `host`, and `heartbeat_at`; freshness is 30 minutes. A fresh
malformed marker fails closed, while a stale well-formed marker is reported and
does not permanently strand the scheduled lane. Every skip appends one JSONL
record to `D:/QM/strategy_farm/logs/headless_orchestration_skip_journal.jsonl`.

No-change rechecks now have an atomic state-hash reservation contract. The
agent supplies canonical JSON containing stable blocker facts and bound hashes
or row IDs, excluding observation timestamps. The wrapper reserves exactly one
marker at
`D:/QM/strategy_farm/state/orchestration_no_change/<agent>/<task>/<sha>.json`.
The first state permits one evidence artifact; repeat observations return its
existing artifact path with `write_allowed=false`. The generated headless
prompt explicitly forbids another timestamped evidence file, OPEN_ITEMS entry,
or commit for the same state hash.

## Code surfaces

| Surface | Change |
|---|---|
| `tools/strategy_farm/agent_scopes.py` | Backward-compatible `spawn_leases` migration adds `owner_token`, `owner_pid`, `owner_host`, and `renewed_at`; atomic expired-only acquisition; exact-owner renew/release; task-router callers retain historical error behavior while headless admission requests fail-closed storage behavior. |
| `tools/strategy_farm/run_agent_orchestration_task.py` | Outer per-agent headless lease, renewal tied to the existing heartbeat, exact release, interactive guard, durable skip journal, state-hash dedupe reservation/CLI, and prompt contract. Slot locks and normal model/quota/work selection remain in place beneath the new outer lease. |
| `tools/strategy_farm/tests/test_agent_scopes.py` | Exact-owner renewal/release and fail-closed headless-storage tests. |
| `tools/strategy_farm/tests/test_agent_orchestration_lock.py` | Real two-thread acquisition race, fresh interactive-marker skip before lease acquisition, prompt contract, and same/different state-hash tests. |

The payload's referenced
`docs/ops/evidence/2026-08-24_claude_orchestration_duplicate_session_race.md`
does not exist in the canonical checkout. Implementation was therefore bound
to the routed title/specification, the live wrapper, current `spawn_leases`
schema, and the duplicate no-change entries already recorded in
`docs/ops/OPEN_ITEMS_STATUS.md`; no missing evidence was fabricated.

## Concurrency and failure semantics

- Acquisition is serialized by SQLite `BEGIN IMMEDIATE` and an atomic
  `INSERT ... ON CONFLICT ... WHERE expires_at <= acquired_at`; the concurrent
  test proves exactly one of two sessions wins.
- A live lease is foreign even when `agent_id` is identical. Same-lane identity
  is never treated as session ownership.
- Renewal requires the exact token, pid, host, unexpired row, and task key.
  Failure raises out of the wait loop and stops the owned model process rather
  than continuing without exclusivity.
- Exact-owner release prevents a late/foreign process from deleting a
  replacement lease. If release storage is unavailable, expiry is the fallback.
- Existing task-router lease callers need no schema/signature change and retain
  the same task-key exclusion semantics.
- With no interactive flag and no competing session, quota selection, work
  discovery, slot behavior, model command construction, timeout, heartbeat,
  push, and result evidence follow the previous path.

## Focused verification

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_agent_scopes.py \
  tools/strategy_farm/tests/test_agent_orchestration_lock.py \
  tools/strategy_farm/tests/test_run_agent_orchestration_heartbeat.py
39 passed

python -m pytest -q \
  tools/strategy_farm/tests/test_codex_model_tiers.py \
  tools/strategy_farm/tests/test_agent_selection_skill_contract.py \
  tools/strategy_farm/tests/test_antigravity_backend_contract.py \
  tools/strategy_farm/tests/test_video_analysis_ai_lanes.py
173 passed

python tools/strategy_farm/run_agent_orchestration_task.py \
  --agent claude --dry-run --max-sessions 1
PASS: returncode 0; dry_run_verified=true; no model launch

python -m compileall -q \
  tools/strategy_farm/run_agent_orchestration_task.py \
  tools/strategy_farm/agent_scopes.py
PASS
```

The production `spawn_leases` table was inspected read-only. The new lease was
tested only against temporary databases; the dry run used the pre-existing
slot lock/prompt path and did not acquire the new production session lease.
No model session, terminal, worker, queue mutation, trading action, T_Live
action, AutoTrading action, or no-change Git commit was created by verification.
