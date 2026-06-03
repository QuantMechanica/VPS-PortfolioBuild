# Gemini v2 build guardrails

Task: `0304dfa3-4558-48b0-9f15-208b8f244fce`
Date: 2026-06-03
Agent: codex

## Verdict

Implemented deterministic guardrails for Gemini v2 rebuilds:

- Gemini orchestration prompt now explicitly forbids raising `qm_news_stale_max_hours` above 336 and tells Gemini to refresh the news calendar seed instead of weakening fail-closed behavior.
- Backtest risk mode is reinforced in the Gemini prompt: `RISK_FIXED > 0`, `RISK_PERCENT = 0`.
- Added `tools/strategy_farm/validate_build_guardrails.py` to scan EA source and setfiles for:
  - `qm_news_stale_max_hours` above 336 in `.mq5` or `.set` artifacts.
  - backtest setfiles with missing/nonpositive `RISK_FIXED`.
  - backtest setfiles with missing/nonzero `RISK_PERCENT`.
- Wired the validator into `tools/strategy_farm/compile_ea.py`, returning `BUILD_GUARDRAILS_FAILED` before MetaEditor compile when artifacts violate the guardrails.
- Wired the same validator into `agent_router.close-review`, so APPROVED close-out is refused when the supplied artifact or payload EA path violates build guardrails.

## Files Changed

- `tools/strategy_farm/validate_build_guardrails.py`
- `tools/strategy_farm/compile_ea.py`
- `tools/strategy_farm/agent_router.py`
- `tools/strategy_farm/run_agent_orchestration_task.py`
- `tools/strategy_farm/tests/test_build_guardrails.py`

## Verification

- `python -m py_compile tools/strategy_farm/validate_build_guardrails.py tools/strategy_farm/compile_ea.py tools/strategy_farm/agent_router.py tools/strategy_farm/run_agent_orchestration_task.py` -> PASS.
- `python -m pytest tools/strategy_farm/tests/test_build_guardrails.py -q` -> not run; `pytest` is not installed in this headless environment.
- Direct execution of all three test functions from `test_build_guardrails.py` -> PASS.
- Real bad-artifact smoke:
  - Command: `python tools/strategy_farm/validate_build_guardrails.py C:/QM/repo/framework/EAs/QM5_10692_tv-ls-ms_v2`
  - Result: FAIL as expected.
  - Finding: `QM5_10692_tv-ls-ms_v2.mq5` has `qm_news_stale_max_hours = 1000000`, above the 336-hour fail-closed bound.

## Re-trigger Boundary

The task requested re-triggering the RECYCLED v2 wave after fixing the process. In this router version, `route-many` only moves `BACKLOG`/`TODO` tasks to `IN_PROGRESS`; it does not route `RECYCLE` tasks. This scheduled Codex cycle is constrained to deterministic router work, so I did not manually mutate RECYCLE tasks into TODO or PIPELINE. The guardrails are now in place for the next controlled recycle/rebuild routing action.
