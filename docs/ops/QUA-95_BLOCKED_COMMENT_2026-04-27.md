Status: **blocked** (defer)

- Issue: QUA-95
- Symbol: XTIUSD.DWX
- Verdict: FAIL_tail_bars
- bars_got: 0
- tail_shortfall_seconds: 7141.322

Unblock owners:
- runtime_custom_symbol_owner: Restore XTIUSD.DWX M1 bars visibility in T1 runtime (bars APIs return non-zero).
- verifier_implementation_owner: After runtime recovery, rerun verifier and confirm bars_got > 0 with aligned tail.

Handoff artifacts:
- docs/ops/QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.md
- docs/ops/QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.json
- docs/ops/QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.sha256
