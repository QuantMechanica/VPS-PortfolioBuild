# MNT-016 — historical verdict taxonomy clean view

Date: 2026-08-21  
Router task: `23922c21-cf9d-4872-a58a-f2eb7a0d0b8b`  
Branch: `agents/board-advisor`  
Source database: `D:/QM/strategy_farm/state/farm_state.sqlite` (read-only)

## Outcome

Historical `work_items` rows remain byte-for-byte untouched. Dashboard database
connections now install the temporary view `work_items_clean` and assert
`PRAGMA query_only=ON` before reading it. The view exposes canonical status,
verdict, taxonomy and verdict-reason fields while retaining `raw_status`,
`raw_verdict`, `raw_verdict_taxonomy`, `raw_verdict_reason`, and explicit
restamp flags for audit.

Both operator renderers (`render_cockpit.py` and
`dashboards/render_dashboards.py`) read `work_items_clean`; a focused AST test
rejects any SQL literal in either renderer that reads `work_items` directly.

## Derived invariant

Schema: `qm.work_items.clean_view.v1`

| Taxonomy | Allowed derived status | Verdict family |
|---|---|---|
| `open` | `pending`, `active`, `claimed` | NULL only |
| `infra` | `failed` | `INFRA_FAIL` |
| `invalid` | `failed` | `INVALID*` |
| `governance` | `failed` | `SUPERSEDED*`, `CANCELLED*`, `BLOCKED*`, `OBSOLETE*` |
| `strategy` | `done` | `PASS*`, `FAIL*`, `ZERO*`, `RETIR*`, and declared strategy tokens |
| `draft_defect` | `done` | `DRAFT_DEFECT` |
| `review` | `done` | review / needs-data / pending-runner dispositions |

Unknown or terminal-NULL combinations fail closed with
`clean_view_valid=0`; they are never silently assigned a known family.
`verdict_reason` is retained unless a strategy verdict carries a known
execution/transport residue such as `ACTIVE_TIMEOUT`, `SUMMARY_MISSING`,
`NO_HISTORY`, `REPORT_MISSING`, or `METATESTER_*`. Suppressed text remains in
`raw_verdict_reason`; legitimate PASS metrics, `PASS_SOFT` probation detail,
and strategy-failure explanations remain visible.

## Live read-only audit

The durable machine report is
`docs/ops/evidence/2026-08-21_mnt016_work_item_clean_view_audit.json`.
At `2026-08-21T13:47:55+00:00` it measured:

- 110,086 source rows;
- 110,086 allowed derived combinations and 0 invariant violations;
- 780 explicit taxonomy restamps;
- 9,325 status restamps, including historical `done/INFRA_FAIL` and
  `failed/strategy` splits;
- 3,737 incompatible stale infra reasons suppressed from strategy display;
- 49,633 missing historical taxonomy fields derived without rewriting them.

Command:

```text
python tools/strategy_farm/work_item_clean_view.py --db D:/QM/strategy_farm/state/farm_state.sqlite --output docs/ops/evidence/2026-08-21_mnt016_work_item_clean_view_audit.json
```

Exit code was 0. The command opens SQLite with `mode=ro`, creates only a TEMP
view on that connection, and switches the connection to query-only.

## Verification

```text
python -m py_compile tools/strategy_farm/work_item_clean_view.py tools/strategy_farm/render_cockpit.py tools/strategy_farm/dashboards/render_dashboards.py tools/strategy_farm/tests/test_work_item_clean_view.py

python -m pytest -q tools/strategy_farm/tests/test_work_item_clean_view.py tools/strategy_farm/tests/test_dashboard_pipeline_books_programme.py tools/strategy_farm/tests/test_gate_manifest.py tools/strategy_farm/tests/test_render_cockpit_cohorts.py tools/strategy_farm/tests/test_render_cockpit_pipeline_books.py tools/strategy_farm/tests/test_verdict_taxonomy_ws2.py
```

Result: `73 passed in 14.52s`.

Additional live read-only smoke:

- cockpit adjacent-cohort snapshot: available;
- archive collection: 2,964 EAs / 110,086 rows;
- full cockpit render: exit 0 in 19.965 seconds;
- current Q06 seven-day `PASS_SOFT` count renders in its own family (7 at the
  smoke timestamp), not as clean PASS and not as an exception.

No factory, terminal, scheduled task, T_Live, AutoTrading, backtest, work-item,
or historical verdict state was started, stopped, rewritten, or advanced.

## Review disposition

The MNT-016 acceptance condition is met on the implementation branch: the
status × verdict × taxonomy invariant is executable and green, and both
operator dashboards consume the derived view. This artifact remains in REVIEW
for Claude/OWNER close-out; it does not self-approve or advance pipeline state.
