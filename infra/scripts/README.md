# Infra Scripts Notes

## `dwx_hourly_check.py`

- `spec_ok` is now evaluated by one shared helper (`is_symbol_spec_ok`) for both:
  - readiness gate (`spec_bad` aggregation)
  - per-symbol readiness report row (`spec_ok` column)
- Criterion:
  - `custom.trade_tick_value > 0`
  - `broker.trade_tick_value > 0`
  - `abs(custom.tv - broker.tv) / broker.tv < 0.05`
- No `tvp` / `tvl` fields are used for gate decisions.
