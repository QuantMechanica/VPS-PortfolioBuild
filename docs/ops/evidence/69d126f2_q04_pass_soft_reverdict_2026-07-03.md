# Q04 PASS_SOFT Re-Verdict Evidence

- Task: `69d126f2-45da-417b-8717-b3a9ac366f2f`
- Refreshed UTC: `2026-07-03T05:50:14+00:00`
- DB: `D:\QM\strategy_farm\state\farm_state.sqlite`
- JSON artifact: `D:\QM\strategy_farm\artifacts\ops\q04_pass_soft_reverdict_20260703_cycle.json`
- Rule: `stored_folds_positive_majority_min12_oos_trades`
- Rule check: `positive_folds >= 2 and oos_trades >= 12`
- Q04 rows currently re-verdicted to `PASS_SOFT`: **70**
- Distinct EAs: **55**
- Records meeting rule check: **70/70**
- Q04 `ea_metrics` verdict counts: `[{'verdict': 'PASS_SOFT', 'count': 70}]`

No MT5 backtests were launched by this evidence pass. The DB already contained the `q04_pass_soft_reverdict` event; this document verifies the re-verdict set and records the Q05 follow-on queue state from the farm DB.

Follow-up cascade completion at `2026-07-03T05:49:00+00:00`: ran the live Q05 cascade helper across all 55 audited EAs. It completed with no errors and requeued 17 existing Q05 rows while leaving already pending/active rows and history-gated rows under the live cascade rules.

## Q05 Follow-On

- Same-setfile Q05 rows present for re-verdicted records: **70/70**
- Same-setfile Q05 total rows: **70**
- Same-setfile Q05 status counts: `{'pending': 68, 'active': 1, 'done': 1}`
- Same-setfile Q05 verdict counts: `{'': 70}`
- Promotion event: `q04_c4_q05_missing_promotions` id `208448` at `2026-07-03T05:36:41+00:00`; created **31**, skipped **39** ({'already_exists_same_setfile': 28, 'cache_history_below_required_oos_window': 11})
- DB backup: `D:\QM\strategy_farm\state\backups\farm_state_before_q04_c4_q05_promote_20260703T053408Z.sqlite`

## Key Rows

| EA | Symbol | Q04 work item | PF-net folds | OOS trades | Q05 rows | Q05 state |
|---|---:|---|---:|---:|---:|---|
| QM5_11128 | SP500.DWX | `eae7ba47-8b32-4ffa-8270-6e22dcc9d3e4` | 0.704, 8.719, 1.684 | 44 | 1 | pending |
| QM5_10919 | XTIUSD.DWX | `af73d92f-7508-4f23-a568-1c60688607f8` | 0.654, 23.093, 12.482 | 13 | 1 | pending |
| QM5_10163 | EURUSD.DWX | `510792fe-7984-4edb-ae2d-21d0496248bf` | 1.447, 0.381, 1.134 | 242 | 1 | pending |
| QM5_10163 | GDAXI.DWX | `f2580791-2f6b-470f-9d76-ba8d7b32cd95` | 1.282, 1.084, 0.768 | 301 | 1 | pending |
| QM5_10911 | EURUSD.DWX | `897fcd02-dbda-45bd-bba4-bfe773f82f00` | 1.046, 1.375, 0.390 | 143 | 1 | pending |
| QM5_10911 | GBPUSD.DWX | `78d85185-cf40-4f01-9347-ef96c015adc3` | 0.579, 1.163, 1.148 | 157 | 1 | pending |
| QM5_10692 | GDAXI.DWX | `8ca6f0c0-2ac5-435f-9ea7-fdfb221365a5` | 0.702, 1.107, 1.403 | 174 | 1 | pending |
| QM5_10440 | XAUUSD.DWX | `c3a39667-3418-4ded-a2ae-428a8985131f` | 0.790, 1.154, 1.034 | 238 | 1 | pending |

## Verification Queries

```sql
SELECT verdict, COUNT(*) FROM work_items WHERE phase='Q04' AND status='done' AND updated_at='2026-07-03T05:24:12+00:00' GROUP BY verdict;
SELECT verdict, COUNT(*) FROM ea_metrics WHERE work_item_id IN (SELECT id FROM work_items WHERE phase='Q04' AND status='done' AND verdict='PASS_SOFT' AND updated_at='2026-07-03T05:24:12+00:00') GROUP BY verdict;
WITH q04 AS (SELECT ea_id,symbol,setfile_path FROM work_items WHERE phase='Q04' AND status='done' AND verdict='PASS_SOFT' AND updated_at='2026-07-03T05:24:12+00:00') SELECT COALESCE(q05.status,'MISSING'), COALESCE(q05.verdict,''), COUNT(*) FROM q04 LEFT JOIN work_items q05 ON q05.phase='Q05' AND q05.ea_id=q04.ea_id AND q05.symbol=q04.symbol AND q05.setfile_path=q04.setfile_path GROUP BY COALESCE(q05.status,'MISSING'), COALESCE(q05.verdict,'');
```
