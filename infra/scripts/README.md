# Infra Scripts Notes

## `dwx_hourly_check.py`

- `spec_ok` is now evaluated by one shared helper (`is_symbol_spec_ok`) for both:
  - readiness gate (`spec_bad` aggregation)
  - per-symbol readiness report row (`spec_ok` column)
- Verifier output is parsed by `summarize_verify_failures(...)` to detect systemic
  runtime patterns before opening per-symbol investigations:
  - `systemic_zero_bars`: >= 10 FAIL rows where all have `bars expected > 0` and `got=0`
  - `systemic_zero_mid_ticks`: >= 10 FAIL rows where all have `mid_ticks_5min=0`
  - These are logged as verifier/runtime conditions, not symbol-specific corruption.
  - Parser contract covers real verifier row shapes with leading verdict spacing
    (for example `[ FAIL_tail_bars] XAGUSD.DWX: ...`) and trailing fields.
- Criterion:
  - `custom.trade_tick_value > 0`
  - `broker.trade_tick_value > 0`
  - `abs(custom.tv - broker.tv) / broker.tv < 0.05`
- No `tvp` / `tvl` fields are used for gate decisions.
