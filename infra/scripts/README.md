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

## `verify_import_preflight_probe.py`

- Non-production helper for targeted verifier investigation on one symbol.
- Compares MT5 read paths directly:
  - `copy_ticks_range(...)` window counts (head/mid/tail)
  - `copy_ticks_from(...)` window counts (head/mid/tail)
  - `copy_rates_range(...)` bar count over sidecar M1 range
- Includes lightweight pre-flight + retries to reduce session/cache timing noise.
- Example:
  - `python C:\QM\repo\infra\scripts\verify_import_preflight_probe.py --symbol XAUUSD.DWX`

## `verify_import_candidate.py`

- Candidate (non-production) verifier behavior for handoff testing.
- Proposed deltas vs live verifier:
  - mid/tail probes use `copy_ticks_from(...)` windows
  - bounded tail tolerance (`--tail-tolerance-ms`, default `180000`)
  - degraded bars classification (`WARN_bars_unavailable`) when ticks exist but M1 bars API returns zero
- Example:
  - `python C:\QM\repo\infra\scripts\verify_import_candidate.py --symbol XAUUSD.DWX`

## `probe_verify_rates_span.py`

- Read-only MT5 probe for verifier investigations.
- Compares one-shot `copy_rates_range(...)` across the full sidecar span vs
  chunked `copy_rates_range(...)` windows.
- Also prints a short tail-window sample (`--tail-hours`, default `24`) and
  symbol metadata (`selected/visible/custom/path`) to distinguish range-query
  param issues from "no bars visible" runtime conditions.
- Use to confirm/quantify range-query limits (`Invalid params` / empty results)
  before classifying a symbol as corrupted.
- Default target is `WS30.DWX`; span comes from latest
  `imports\\done\\*_<symbol>.import.txt`.

## `verify_import_chunked_probe.py`

- Read-only verifier mirror for symbol-level deep dive.
- Reuses verifier checks (head/tail/mid/spec) and compares:
  - full-span `copy_rates_range(...)` count
  - chunked `copy_rates_range(...)` count
- Prints `terminal_maxbars` so evidence can distinguish:
  - MT5 chart-history cap effects (for example 100k cap), vs
  - genuine zero-bars visibility for a symbol.

## `verify_import_chunked_probe.py`

- Non-production probe that mirrors `verify_import.py` checks for one symbol.
- Keeps tick checks intact, but compares:
  - one-shot full-span M1 read (current verifier shape)
  - chunked M1 range reads (diagnostic/fix candidate)
- Helps decide whether `FAIL_bars` is query-shape/API-limit related vs data loss.
- Also reports source-vs-custom tail parity (`custom_minus_source_tail_ms`) so
  tail failures can be classified as symbol corruption vs expectation-basis mismatch.

## `Invoke-VerifyDisposition.ps1`

- Idempotent verifier rerun helper for issue triage.
- Runs `verify_import.py`, captures a timestamped raw log under `infra\\smoke\\`,
  parses FAIL rows, and writes tracked evidence JSON under
  `lessons-learned\\evidence\\`.
- Emits symbol-level disposition:
  - `clear`: `bars_got > 0` and tail timestamps aligned
  - `defer`: systemic zero-bars pattern or symbol bars still zero
  - `fix`: not clear/defer; investigation still in-flight
- Example:
  - `powershell -File C:\QM\repo\infra\scripts\Invoke-VerifyDisposition.ps1 -IssueId QUA-92 -Symbol XAGUSD.DWX`
