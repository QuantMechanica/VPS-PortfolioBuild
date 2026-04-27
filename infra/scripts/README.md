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
    (for example `[ FAIL_tail_bars] XAGUSD.DWX: ...` and
    `[FAIL_tail_mid_bars] XNGUSD.DWX: ...`) and trailing fields.
- One-command triage on a captured verifier log:
  - `python -c "from pathlib import Path;import importlib.util as u;p=Path(r'C:\QM\repo\infra\scripts\dwx_hourly_check.py');s=u.spec_from_file_location('m',p);m=u.module_from_spec(s);s.loader.exec_module(m);t=Path(r'C:\QM\repo\infra\smoke\verify_import_run_2026-04-27_qua19.log').read_text(encoding='utf-8',errors='replace');print(m.summarize_verify_failures(t))"`
- Criterion:
  - `custom.trade_tick_value > 0`
  - `broker.trade_tick_value > 0`
  - `abs(custom.tv - broker.tv) / broker.tv < 0.05`
- No `tvp` / `tvl` fields are used for gate decisions.

## `probe_verify_rates_span.py`

- Read-only MT5 probe for verifier investigations.
- Compares one-shot `copy_rates_range(...)` across the full sidecar span vs
  chunked `copy_rates_range(...)` windows.
- Use to confirm/quantify range-query limits (`Invalid params` / empty results)
  before classifying a symbol as corrupted.
- Default target is `WS30.DWX`; span comes from latest
  `imports\\done\\*_<symbol>.import.txt`.
