# QUA-739 Transition Recommendation (2026-05-05)

Issue: QUA-739 (QM5_1003 P2 dedup not cleared)

## Recommendation
Transition QUA-739 scope to **resolved for dedup objective** and track remaining MT5/run_smoke failures as a separate infra blocker owner thread (CTO / Framework Ops).

## Basis
1. Dedup objective achieved and stable:
   - `dispatch_state.json` dedup keys matching `QM5_1003|v1|*|P2|H1-2024` repeatedly verified at `0`.
   - dry-run repeatedly schedules full 36-symbol set without duplicate skip blockage.
2. Remaining failures are infra execution/materialization, not dedup logic:
   - `REPORT_MISSING`, `METATESTER_HUNG`, `no_summary_json`.
3. Runtime hygiene tooling and controls are now in place:
   - `framework/scripts/qm5_1003_guarded_sweep.ps1`
   - periodic guarded sweeps + cleanup evidence in `docs/ops/QUA-739_HEARTBEAT_...`

## Current Runtime State at Recommendation Time
- active QM5_1003 python runners: `0`
- active QM5_1003 tester terminals: `0`
- latest guarded sweep: `docs/ops/QUA-739_GUARDED_SWEEP_20260505T192429+0200.json`
- residual tester cleanup executed: PID `29984`

## Suggested Next Workflow
- Keep QUA-739 as blocked/resolved-for-scope note (no further looped heartbeats required on dedup).
- Open or continue CTO/Framework Ops infra ticket for MT5 materialization reliability.
- Resume canonical full P2 only after infra owner provides unblock confirmation.
