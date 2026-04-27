# Infra Scripts Notes

## `dwx_hourly_check.py`

- `spec_ok` is now evaluated by one shared helper (`is_symbol_spec_ok`) for both:
  - readiness gate (`spec_bad` aggregation)
  - per-symbol readiness report row (`spec_ok` column)
- Criterion:
  - `trade_tick_value_profit > 0`
  - `trade_tick_value_loss > 0`
  - `currency_base` and `currency_profit` are both populated
- `trade_tick_value` equality checks (`tv == tvp == tvl`) are intentionally not part of readiness.
