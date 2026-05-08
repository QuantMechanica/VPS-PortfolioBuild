# QUA-95 Blocked State Assertion (2026-04-27)

Issue: QUA-95  
Generated from canonical artifacts at $generatedAt.

## Current gate

- ecommended_state=clear
- eason=acceptance_met
- disposition=clear
- ars_got=99911
- 	ail_shortfall_seconds=7141.322

## Source artifacts

- docs/ops/QUA-95_GATE_DECISION_2026-04-27.json
- docs/ops/QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json
- docs/ops/QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.sha256

## Unblock owners

1. $(@{owner=runtime_custom_symbol_owner; required_action=Restore XTIUSD.DWX M1 bars visibility in T1 runtime (bars APIs return non-zero).}.owner)
- Restore XTIUSD.DWX M1 bars visibility in T1 runtime (bars APIs return non-zero).

2. $(@{owner=verifier_implementation_owner; required_action=After runtime recovery, rerun verifier and confirm bars_got > 0 with aligned tail.}.owner)
- After runtime recovery, rerun verifier and confirm bars_got > 0 with aligned tail.
