# QM5_12624 Q02 news-off setfile repair and requeue

Date: 2026-06-28
Agent: codex board advisor
Scope: `QM5_12624_edgelab-eurjpy-audjpy-cointegration`

## Why this was selected

`QM5_12624` is a diverse FX market-neutral basket (`EURJPY.DWX` / `AUDJPY.DWX`).
It had no active/pending work item at selection time and its latest Q02 attempts
failed as infrastructure, not as strategy verdicts:

- `53f8fa92-3452-48ed-9e7c-82344a76883c` - `INFRA_FAIL`
- `9461ba0f-5de6-490e-8d85-380738abd892` - `INFRA_FAIL`
- `1489f74b-7259-484d-9237-452331b0e478` - `INFRA_FAIL`

The latest evidence reached real EURJPY/AUDJPY order execution, then failed
report export with `REPORT_MISSING`, `METATESTER_HUNG`, and `INCOMPLETE_RUNS`.
There was no OnInit failure and no no-history classification.

## Diagnosis

The fixed-risk Q02 setfile carried only the older placeholder news keys:

- `qm_filter_news_enabled=1`
- `qm_filter_news_mode=3`

The EA uses the current FW1 news inputs. Because the setfile did not set them,
the tester used EA defaults:

- `qm_news_temporal=QM_NEWS_TEMPORAL_PRE30_POST30`
- `qm_news_compliance=QM_NEWS_COMPLIANCE_DXZ`

That makes Q02 load and query the news calendar during a full-tick FX basket run.
The basket checks both legs, so the prior run spent avoidable time in news logic
before timing out without a final report.

## Repair

Updated the canonical Q02 backtest setfile:

- added `qm_news_temporal=0`
- added `qm_news_compliance=0`
- added `qm_news_mode_legacy=0`
- added `qm_news_stale_max_hours=336`
- added `qm_news_min_impact=high`
- changed `qm_filter_news_enabled=0`
- changed `qm_filter_news_mode=0`

Risk and basket metadata were unchanged:

- `RISK_FIXED=150000`
- `tester_currency=JPY`
- `tester_deposit=15000000`
- host symbol `EURJPY.DWX`
- logical symbol `QM5_12624_EURJPY_AUDJPY_COINTEGRATION_D1`

## Validation

Command:

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12624_edgelab-eurjpy-audjpy-cointegration
```

Result:

- `compile_one.result=PASS`
- `compile_one.errors=0`
- `compile_one.warnings=0`
- `build_check.result=PASS`
- `build_check.failures=0`
- `build_check.warnings=16` framework include advisories only
- build report: `D:\QM\reports\framework\21\build_check_20260628_085156.json`
- compile log: `C:\QM\repo\framework\build\compile\20260628_085156\QM5_12624_edgelab-eurjpy-audjpy-cointegration.compile.log`

No manual MT5 launch, no T_Live interaction, and no AutoTrading change.

## Farm DB enqueue

Backed up DB before mutation:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12624_news_off_q02_requeue_20260628_085340.sqlite`

Inserted pending Q02 work item:

- work item: `f346f9e9-7dc9-4cff-be60-4dec96784e77`
- phase: `Q02`
- status: `pending`
- supersedes: `1489f74b-7259-484d-9237-452331b0e478`
- setfile: `C:\QM\repo\framework\EAs\QM5_12624_edgelab-eurjpy-audjpy-cointegration\sets\QM5_12624_edgelab-eurjpy-audjpy-cointegration_QM5_12624_EURJPY_AUDJPY_COINTEGRATION_D1_D1_backtest.set`
- reason: `infra_repair_news_off_setfile_after_metatester_hung`
