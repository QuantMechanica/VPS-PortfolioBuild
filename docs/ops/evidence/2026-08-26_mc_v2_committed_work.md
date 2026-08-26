# Mission Control v2 committed-work telemetry — 2026-08-26

Task: `9eece278-b198-4d8a-91d1-27e6628354b3`

## Outcome

Mission Control's **Weg zu 25** section now exposes committed cell budgets that
are not visible in the ordinary `work_items` backlog until they materialize.
The read-only model reports, per Q-only class, `declared`, `materialized`, and
`receipts`, plus the total still unmaterialized.

Live read at verification time:

| Class | Parents | Declared | Materialized | Receipts | Unmaterialized |
|---|---:|---:|---:|---:|---:|
| Q12_PATTERN | 3 | 3,267 | 0 | 0 | 3,267 |
| Q10_NEWS | 50 | 772 | 0 | 0 | 772 |
| **Total** | **53** | **4,039** | **0** | **0** | **4,039** |

Q12 totals come from each open parent's `pattern_filter_sweep.annual_cell_count`
plus `wf_cell_count`; deterministic declared child IDs are joined to existing
rows. Q10_NEWS totals come from `planned_cell_count` / `q09_cell_count` and
authenticated receipt counts in the parent payload. No constants define the
cell budget, and no queue/dispatch write occurs.

## Verification

```text
python -m py_compile tools/strategy_farm/path_to_25.py tools/strategy_farm/render_cockpit_v2.py tools/strategy_farm/mission_control_v2_data.py
python -m pytest tools/strategy_farm/tests/test_path_to_25_metrics.py tools/strategy_farm/tests/test_render_cockpit_v2.py tools/strategy_farm/tests/test_mission_control_v2_data.py -q
25 passed, 1 skipped in 4.74s
```

The fixture test covers payload-derived Q12 and Q10_NEWS totals, materialized
rows, authenticated receipts, and the zero-parent case. The screenshot was
captured from a fresh live-contract render:

- Screenshot: `C:/QM/repo/docs/ops/evidence/2026-08-26_mc_v2_committed_work.png`
- Review HTML: `D:/QM/strategy_farm/dashboards/cockpit_committed_work_review.html`

The review HTML is a disposable rendered view; the durable evidence is this
document and the PNG in the canonical checkout.
