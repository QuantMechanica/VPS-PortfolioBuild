# QM5_39007 review rework closure

RESULT: REVIEW_READY — the approved-card start-hour control is wired, focused tests pass 7/7, and governed COMPILE_EA work item `fd0e0d66-03c4-4c16-9318-97bd10f42289` completed `COMPILE_OK` with 0 errors, 0 warnings, and build-check PASS.

Router task: `8b09ed22-3d26-41a0-8eb3-d7df0bd66331`  
EA: `QM5_39007_forexfactory-100-pips-early-bird-breakout`

## Disposition

The review text attached to the requeued task described the pre-rework source in
which `InpBoxStartHourUTC` was declaration-only. That defect was already repaired
by commit `24da8f25610022d31c7f878a0f3ccc66ec3a6dae`
(`rework(39007): restore pending breakout contract`). The canonical source is
clean and byte-identical to that reviewed repair, so no second strategy-logic
edit was made.

The current source uses the input in both dimensions that define the box:

- line 301 computes `(InpBoxEndHourUTC - InpBoxStartHourUTC) * 4` completed
  M15 bars;
- line 307 reads exactly those completed bars with shift 1; and
- line 312 derives the inclusive lower time boundary from
  `InpBoxStartHourUTC * 60`, while the loop rejects any bar outside
  `[start, end)`.

Thus changing the start input changes the number of sampled bars and the
accepted UTC lower boundary. It cannot produce the old identical optimization
surface unless the underlying prices happen to do so.

Pre-flight identity is valid: the approved card has `g0_status: APPROVED`, the
card/EA/registry slug is identical, `ea_id_registry.csv` has active EA 39007,
and `magic_numbers.csv` has active GBPUSD slot 0 and EURUSD slot 1 rows.

## Governed compile

The source hash was already covered by a prior governed receipt, but the tracked
EX5 bytes had drifted back to the older binary hash
`67ca627d8976fcdc3a6c7514f9ff288f988d43d1150b354536806930a1c76bba`.
No ad-hoc compiler was used. The existing exact source-repair authority
`router_build_rework:8b09ed22-3d26-41a0-8eb3-d7df0bd66331:QM5_39007`
created one append-only COMPILE_EA row, and its exact activation hold was
released through the governed compile-wave ceremony. Resident worker T3 claimed
and completed it.

Receipt:
`D:/QM/reports/work_items/fd0e0d66-03c4-4c16-9318-97bd10f42289/QM5_39007/COMPILE_EA/compile_evidence.json`

| Binding | SHA-256 / result |
|---|---|
| MQ5 | `4279a0fd50827b6f54510a8a2a0168153656c60f15b969fbfee407519bc5389d` |
| EX5 | `d35c8a62f75e51b05903401088d5a296e1ede3a3e8330388e0c849165e51538c` |
| Include closure | `47f4a31b62bdcb2978f7920422a0f71ea9d2088f1539f3c33d95fbb3b6096c5c` |
| Compile | `PASS`, 0 errors, 0 warnings |
| Build check | `PASS`, 0 failures, 0 warnings |
| Setfiles | 2, both regenerated with `RISK_FIXED=1000` and `RISK_PERCENT=0` |

## Focused verification

```text
PYTHONDONTWRITEBYTECODE=1 python -m pytest -q -p no:cacheprovider \
  tools/strategy_farm/tests/test_qm5_39007_review_rework.py
.......                                                                  [100%]
7 passed
```

The focused test asserts the start/end box span, shift-1 `CopyRates`, strict
`[start,end)` bar membership, pending-stop straddle/OCO wiring, and both fixed-
risk setfiles. `audit_framework_input_pins.py --check-source` also returned
`ok=true`, `hit_count=0`. `validate_build_guardrails.py` returned PASS with no
findings for the MQ5 and both regenerated setfiles; the news-staleness ceiling
remains 336 hours.

This is build evidence only. No Q phase, backtest, gate verdict, live package,
terminal chart, T_Live, or AutoTrading state was started or changed.
