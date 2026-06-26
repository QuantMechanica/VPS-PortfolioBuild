# QM5_12585 Launch-Fault Guard And Q02 Requeue - 2026-06-26

Scope: branch `agents/board-advisor`; no `T_Live`, deploy manifest, portfolio gate, or AutoTrading changes.

## Target

- EA: `QM5_12585_eia-rbob-pullback`
- Instrument: `XTIUSD.DWX` D1
- Diversity role: non-XNG energy sleeve; gasoline/RBOB pullback proxy on WTI
- Q02 work item requeued: `6139b29e-5a72-4784-a3c3-7280e114141b`

## Diagnosis

The Q02 failures for `QM5_12585` did not produce MT5 evidence:

- `evidence_path=NULL`
- per-item logs were empty
- worker payload ended with `final_failure=summary_missing_retries_exhausted`
- terminal-worker logs show repeated sub-second launch faults:
  - `T3`: work item `79b87368-fa81-41ed-9b46-b5d40b0e6671`, `ran_seconds=0.05`
  - `T5`: work item `6139b29e-5a72-4784-a3c3-7280e114141b`, `ran_seconds=0.05-0.06`

This is host/terminal launch infrastructure, not a strategy verdict.

## Worker Fix

Patched `tools/strategy_farm/terminal_worker.py`:

- serialize terminal startup more tightly by default:
  - `LAUNCH_GATE_MAX_CONCURRENT=1`
  - `LAUNCH_GATE_WINDOW_SECONDS=15`
- defer sub-second `launch_fault` rows without consuming `attempt_count`
- add `launch_not_before_utc` cooldown handling in `claim_atomic`

Runtime override applied for currently running workers:

- `D:/QM/strategy_farm/state/launch_gate_max.txt = 1`

## Follow-Up Finding

The first requeue got past terminal launch, but the worker killed the run via log-bomb guard:

- terminal: `T5`
- journal size: about `1.0 GB`
- worker result: `log_bomb_killed`
- report existed but no `summary.json` was produced before the guard deleted the oversized tester journal

The EA source already matched the repo version with strategy work behind the D1 `QM_IsNewBar()` gate; no EA source diff was committed in this turn. The log-bomb is therefore recorded as a separate remaining blocker if the requeued run repeats it.

## Q02 Requeue

Reset work item `6139b29e-5a72-4784-a3c3-7280e114141b`:

- `status`: `failed` -> `pending`
- `verdict`: `INFRA_FAIL` -> `NULL`
- `attempt_count`: `99` -> `0` after the log-bomb discovery
- stale launch fields removed from payload
- payload records `requeued_by=codex_board_advisor_ea_hotpath_fix`

## Validation

- `python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py` -> `12 passed`
- `python -m py_compile tools/strategy_farm/terminal_worker.py tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py` -> PASS
- `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12585_eia-rbob-pullback/QM5_12585_eia-rbob-pullback.mq5 -Strict` -> PASS, 0 errors, 0 warnings
