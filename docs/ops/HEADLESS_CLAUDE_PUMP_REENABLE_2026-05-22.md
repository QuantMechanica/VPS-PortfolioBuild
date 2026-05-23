# Headless Claude Pump Re-enable

Date: 2026-05-22
Router task: `726b481c-94fa-4e4a-b583-94ae69cd31fd`
Status: REVIEW
Verdict: HEADLESS_CLAUDE_PUMP_READY

## Task

OWNER authorized re-enabling headless Claude spawning. The pump had hard-disabled Claude by setting:

- `MAX_PARALLEL_CLAUDE = 0`
- `prefer_claude_review = False`
- hardcoded false `claude_review_spawn`
- hardcoded false `claude_g0_spawn`
- hardcoded false `claude_research_spawn`

## Changes

- `tools/strategy_farm/farmctl.py`
  - Claude cap is now `1` when `D:/QM/strategy_farm/CLAUDE_DISABLED.flag` is absent.
  - Claude cap is `0` when the disabled flag exists.
  - `claude_review_spawn` calls `_spawn_claude_for_review(...)` when a review candidate exists and cap allows.
  - `claude_g0_spawn` calls `_spawn_claude_for_g0_batch(...)` when no higher-priority review spawned and cap allows.
  - `claude_research_spawn` calls `_claim_research_source(...)` only when the research replenishment gate allows new research and cap allows.
  - Codex review/G0/research logic remains available as fallback or independent capacity.
- `tools/strategy_farm/agent_router.py`
  - Temporary/non-default router roots now honor their own `CLAUDE_DISABLED.flag` when `status(root)` is called without an explicit flag path.
  - This preserves the production default flag path while fixing the root-local disabled-flag contract used by tests and isolated runs.

## Verification

- `python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/agent_router.py`
  - PASS
- `python -m pytest tools/strategy_farm/tests/test_agent_router.py`
  - PASS: 17 passed
- Isolated pump smoke, Claude enabled and active count stubbed to 0:
  - `claude_disabled=false`
  - `max_parallel_claude=1`
  - `claude_review_spawn.spawned=true`
  - `codex_review_spawn.spawned=false`, reason `claude review spawned`
- Isolated pump smoke with root-local `CLAUDE_DISABLED.flag`:
  - `claude_disabled=true`
  - `max_parallel_claude=0`
  - `claude_review_spawn.spawned=false`, reason `CLAUDE_DISABLED.flag present; routed to Codex`
  - Codex fallback path remained callable.

## Guardrails

- No live-scope path was touched.
- No T_Live or AutoTrading action was taken.
- No `terminal64.exe` process was started manually.
- The live pump was not invoked; pump behavior was verified through isolated temporary-root smoke runs with spawn helpers stubbed to avoid consuming real Claude/Codex work.

