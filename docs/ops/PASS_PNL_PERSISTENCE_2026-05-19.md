# PASS PnL Persistence Backfill - 2026-05-19

## Diagnosis

- `farmctl.dispatch_work_items()` classified `summary.json` into a PASS/FAIL verdict and persisted `verdict_reason`, but dropped the run metrics already present in the summary.
- `recover_orphan_reports.py` already used `payload_json.recovered_stats` for recovered report PnL. The dashboard renderer consumes that same key for Strategy Archive PnL.
- Regular `D:\QM\reports\work_items\...\summary.json` and pipeline `D:\QM\reports\pipeline\...\summary.json` files both expose run metrics under `runs[]`: `net_profit`, `total_trades`, `profit_factor`, and `drawdown`.

## Fix

- New PASS work_items now persist `payload_json.recovered_stats` from the same `summary.json` saved as `evidence_path`.
- Historical PASS rows were backfilled with `tools/strategy_farm/backfill_pass_pnl.py`.

## Verification

- Before: 296 PASS work_items missing `recovered_stats`.
- Backfill: checked 296, updated 296, skipped unreadable 0, skipped no-stats 0.
- After: 0 PASS work_items missing `recovered_stats`; 296 PASS work_items have numeric `recovered_stats.net_profit`.
- Dashboard render completed: `D:\QM\strategy_farm\dashboards\strategies.html`.
- Rendered Strategy Archive currently has 4 distinct EA archive rows with Net P&L because the 296 PASS work_items aggregate to 4 distinct `ea_id` values in the current DB.
