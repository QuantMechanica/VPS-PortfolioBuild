# QM5_2133 USDJPY Q02 Infra Requeue

Date: 2026-07-07

Unit: repaired the stranded-INFRA enqueue path for `QM5_2133_demark-td-trend-factor-h4` on `USDJPY.DWX` and inserted one targeted Q02 pending row.

Why this target:
- Diversity: Forex `USDJPY.DWX`, H4 cadence.
- Approved structural card: `QM5_2133_demark-td-trend-factor-h4`, DeMark TD-Trend-Factor; fixed price-only rules, no ML/grid/martingale.
- Prior row: `4e02a392-adda-4a4c-9bde-5ab6aa29b0ac`, Q02 `INFRA_FAIL`, `summary_missing_retries_exhausted`, no strategy verdict.
- No pending/active duplicate existed before requeue.

Fix:
- `tools/strategy_farm/sweep_enqueue_built_eas.py` now accepts `ea_id_registry.csv` rows keyed as `QM5_<digits>`, not only bare numeric ids.
- This removed the false `registry_status=None` skip for `QM5_2133`.

Validation:
- `compile_one.ps1 -EALabel QM5_2133_demark-td-trend-factor-h4 -Strict`: PASS, 0 errors, 0 warnings.
- `build_check.ps1 -EALabel QM5_2133_demark-td-trend-factor-h4 -Strict -SkipCompile`: PASS, 0 failures, 0 warnings.
- Dry-run sweep after parser fix: one targeted Q02 enqueue candidate for `QM5_2133` / `USDJPY.DWX`.

Queue result:
- New work item: `097d12fd-61ad-4851-9da0-c8cf864d9b32`
- Phase: `Q02`
- Status: `pending`
- Setfile: `C:\QM\repo\framework\EAs\QM5_2133_demark-td-trend-factor-h4\sets\QM5_2133_demark-td-trend-factor-h4_USDJPY.DWX_H4_backtest.set`
- Enqueued by: `claude_sweep_enqueue_2026-06-10.stranded_infra_fail`

Scope guard:
- No T_Live, AutoTrading, portfolio gate, or T_Live manifest changes.
