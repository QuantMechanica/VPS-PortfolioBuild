# QUA-95 Blocked State Assertion (2026-04-27)

Issue: `QUA-95`  
Generated from canonical artifacts at `2026-04-27T10:19:13+02:00`.

## Current gate

- `recommended_state=blocked`
- `reason=acceptance_not_met`
- `disposition=defer`
- `bars_got=0`
- `tail_shortfall_seconds=7141.322`

## Source artifacts

- `docs/ops/QUA-95_GATE_DECISION_2026-04-27.json`
- `docs/ops/QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json`
- `docs/ops/QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.sha256`

## Unblock owners

1. `runtime_custom_symbol_owner`
- Restore `XTIUSD.DWX` M1 bars visibility in T1 runtime (`copy_rates_range`/`copy_rates_from_pos` non-zero).

2. `verifier_implementation_owner`
- After runtime recovery, rerun verifier and confirm `bars_got > 0` with aligned tail.
