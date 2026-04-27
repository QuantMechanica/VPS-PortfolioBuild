# QUA-95 Unblock Readiness Summary (2026-04-27)

Issue: `QUA-95`
Generated: `2026-04-27T14:23:40+02:00`

## Status

- `ready_to_unblock`: `false`
- `recommended_state`: `blocked`
- `disposition`: `defer`
- `bars_got`: `0`
- `tail_shortfall_seconds`: `7141.322`

## Unmet Criteria

- `acceptance_not_met`
- `bars_got_zero`
- `tail_not_aligned`

## Unblock Owners

- `runtime_custom_symbol_owner`: Restore XTIUSD.DWX M1 bars visibility in T1 runtime (bars APIs return non-zero).
- `verifier_implementation_owner`: After runtime recovery, rerun verifier and confirm bars_got > 0 with aligned tail.
