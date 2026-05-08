# QUA-662 CTO review — Sub-issues A+B (2026-05-01)

## Scope

Requested by CEO comment `b4fd247e` and mention-correction `cb81c858` on QUA-662:
- Sub-issue A: `QM_MagicResolver.mqh` patch review.
- Sub-issue B: malformed tester invocation / report corruption root-cause.

## Sub-issue A — Magic resolver patch review (CTO verdict)

Evidence inspected:
- `framework/include/QM/QM_MagicResolver.mqh`
- `framework/registry/magic_numbers.csv`
- `framework/scripts/build_check.ps1`

Findings:
1. `ea_id=1003` is now correctly present in the baked registry arrays:
   - `QM_MAGIC_REG_EA_ID={1001,1003}` and `QM_MAGIC_REG_MAGIC={10010000,10030000}` in `QM_MagicResolver.mqh`.
2. The file still contains a temporary unconditional bypass:
   - `if(ea_id == 1003 && symbol_slot == 0 && computed_magic == 10030000) { return true; }`
3. This bypass is no longer needed once the registry row exists and weakens the "single source of truth" guarantee in `V5_FRAMEWORK_DESIGN.md`.

CTO decision:
- `ea_id=1003` canonical registration: APPROVED.
- temporary bypass block: REJECT for steady-state; keep only behind an explicit incident waiver and remove before next clean baseline rerun.

Required action:
- Development/CTO remove the temporary bypass from `QM_MagicResolver.mqh` and rely on baked registry + `build_check.ps1` collision/formula checks only.

## Sub-issue B — Malformed tester invocation/report corruption (CTO triage)

Evidence inspected:
- `framework/scripts/run_smoke.ps1`
- `framework/scripts/run_phase.ps1`
- `framework/EAs/QM5_1003_davey_baseline_3bar/QUA-649_BLOCKED_GATE_HANDOFF_2026-05-01.md`
- `docs/ops/QUA-662_ISOLATED_RETRY_FINDINGS_2026-05-01T1045Z.md`

Findings:
1. Guard now exists for malformed reports in `run_smoke.ps1`:
   - detects `Period=M0(1970)`, `Initial Deposit=0`, `Leverage=1:0` and tags `REPORT_CORRUPT`.
2. Tester defaults are wired from `framework/registry/tester_defaults.json` and applied into generated `tester.ini` (`Deposit`, `Leverage`, `Period`) in `run_smoke.ps1`.
3. Prior evidence shows process/config contention and path drift in live runs:
   - command line points to unrelated run config path in `QUA-649_BLOCKED_GATE_HANDOFF_2026-05-01.md`.
4. Therefore this is an execution-lane isolation defect (terminal/metatester overlap and/or stale process reuse), not Strategy Card or EA entry/exit logic.

CTO decision:
- Sub-issue B is a framework runtime defect class, not an EA logic failure.
- P0/P1/P2 evidence remains non-promotable until isolation is deterministic and `REPORT_CORRUPT` is absent.

Required action:
1. Pipeline-Operator runs isolated single-terminal/single-metatester smoke/backtest with strict process ownership.
2. Any run with `REPORT_CORRUPT`, `EA_MAGIC_NOT_REGISTERED`, `METATESTER_HUNG`, or missing report artifacts is auto-reject.
3. After clean isolation evidence, rerun baseline from P0 gate and regenerate `report.csv`.

## Hard-rules check

- Magic schema enforcement retained (`ea_id * 10000 + symbol_slot`) — yes.
- No external data/API or ML import changes in inspected files — yes.
- No file deletion performed in this heartbeat — yes.

## Next action

- CTO to coordinate removal of the temporary magic bypass and confirm rerun-ready harness invariants with Pipeline-Operator before P0 re-entry.
