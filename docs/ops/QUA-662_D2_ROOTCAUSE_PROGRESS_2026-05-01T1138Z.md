# QUA-662 D2 root-cause progress (2026-05-01T11:38Z)

## Concrete probe executed

- Live MT5 API checks on the 21-symbol D2 fail cohort.
- Evidence file: `docs/ops/QUA-662_D2_TICKS_VS_RATES_DIAG_2026-05-01T1136Z.json`

## Result (critical)

- `ticks_ok_count = 21`
- `rates_ok_count = 0`
- `ticks_ok_rates_fail_count = 21`

Interpretation:
- Custom symbols are present and tick stream is readable.
- M1 rates are not readable/populated for all 21 failing symbols.
- D2 blocker is now narrowed to **custom-bar ingestion/access path** (rates layer), not symbol registration or tick import.

## Operational implication

- Any launcher/verifier that depends on `copy_rates_*` for these symbols will fail gate checks regardless of EA behavior.
- Baseline remains non-runnable under DL-054 Gate 1 until rates layer is restored.

## Unblock owner/action

- owner: CTO + Pipeline-Operator
- action:
1. Repair/reload M1 rates for the 21-symbol cohort in T1 custom symbol store.
2. Re-run `verify_import.py` and require `21/21` pass.
3. Keep QUA-662 blocked until rates-ok evidence is present.
