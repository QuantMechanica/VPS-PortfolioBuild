# Dashboard UX Overhaul — Progress 2026-05-21

Router task: 90e8927f-29a0-446c-a53a-d63dfaccae32 (dashboard_ux_overhaul)
Agent: claude · State: IN_PROGRESS
Started ahead of the 2026-05-22 00:00 blocked_until gate on explicit OWNER instruction
(CLAUDE_DISABLED.flag — the canonical enable control — was already removed).

## Pass 1 — DONE: Cockpit (`current.html`)

`render_current()` in `tools/strategy_farm/dashboards/render_dashboards.py` was rebuilt
from a verbose recency dump into an operator decision view. Verified:

```
python -m py_compile tools/strategy_farm/dashboards/render_dashboards.py tools/strategy_farm/render_cockpit.py   # OK
python tools/strategy_farm/dashboards/render_dashboards.py   # OK — current.html + strategies.html + 167 detail pages
python tools/strategy_farm/render_cockpit.py                 # OK — cockpit.html unaffected
```

Output sanity: 9 `<section>` balanced, 2 `<details>` balanced, 4 `<table>` balanced.

### What changed

New first-viewport **Current Decision State** band: Q11/P8-PASS candidate count,
MT5 fleet running, pipeline backlog, active bottleneck, and a single bold
**Next action** line derived from live state.

Replaced the old verbose/recency content with operator-grade sections:

- **Pipeline Queue Health** — per-phase pending / active / PASS / FAIL / INVALID / total.
- **Live Pipeline vs Strategy Archive** — `distinct_eas_in_work_items`,
  `rendered_ea_detail_pages`, `db_eas_without_detail_page`,
  `archive_pages_without_current_work_items`; explicit note that the archive row
  count is not live factory progress. Expandable gap list of DB EAs missing a page.
- **Daily Controlling** — real MT5 runs / distinct EAs / PASS / FAIL / INVALID /
  preflight-rejected for Today, Yesterday, 7d, 30d. A work item counts as a real
  MT5 backtest only if it actually launched a tester run (terminal claim /
  run_smoke exit / report evidence); preflight rejects are excluded.
- **Build Artifact Integrity** — preflight / missing-`.ex5` / missing-setfile
  failures grouped by reason with affected EA ids, flagged as build defects, not
  strategy FAILs.
- **Agent Router** — open `agent_tasks` (non-terminal states) with type, state,
  agent, priority, SLA age; surfaces the blocked Claude task and active Codex/Gemini.
- **Needs Attention** — issues grouped by reason and severity, replacing the old
  raw repeated blocker wall.
- Expandable pending-work-items list (EA / symbol / phase, capped at 120).

New code: `collect_cockpit_data()`, `derive_next_action()`, `_wi_payload()`,
`_ran_real_mt5()`, `_age_hours()`, 7 section renderers, `COCKPIT_CSS`.
The old `render_throughput` / `render_pipeline_table` / `render_blockers` /
`render_events` are no longer called by `current.html` (left defined, harmless).

### Residual limitations (pass 1)

- The `work_items` schema has no `execution_kind` column, so Q10-style Python-only
  analysis gates cannot be cleanly separated from MT5 tester runs inside
  `work_items`. The renderer classifies MT5-vs-preflight heuristically and the
  Daily Controlling note states this. A clean split needs a repo-level schema add.

## Pass 2 — REMAINING

Not yet done — task stays IN_PROGRESS:

- **Strategy Archive (`strategies.html`)** — summary chips (P8 / P4+ / active /
  dead / not-started), default surface decision candidates before dead rows,
  filter presets, split "Best Net P&L" into exploratory-vs-gate columns,
  archive-only vs live-pipeline row labels.
- **EA detail pages (`ea_*.html`, esp. `ea_QM5_1056.html`)** — decision header,
  substantive strategy description with source attribution, pipeline-stage
  `<details>` accordion (Q11→Q02) with symbol/timeframe-level evidence, P8-first
  ordering, grouped failure reasons.

These touch `render_strategies`, `collect_ea_lead_kpis`, `collect_ea_detail`,
`render_ea_detail` and the `.archive-*` / `.detail-*` / `.phase-section` CSS.
