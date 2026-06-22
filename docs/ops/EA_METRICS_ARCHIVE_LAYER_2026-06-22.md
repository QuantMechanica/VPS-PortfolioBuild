# ea_metrics — Strategy Archive Metric Layer & Q02→Q03 Promotion Fix

**Date:** 2026-06-22 · **Author:** Claude · **Commits:** `970b5490d` (archive layer),
`369ebb390` (pump starvation fix), this doc + `chk_ea_metrics_fresh`.
**Branch:** `agents/board-advisor` (the live factory trunk; `main` is far behind and not
the operational trunk — see `git worktree list`).

---

## TL;DR

The Strategy Archive (`ea_<id>.html` detail pages + `strategies.html`) showed
`$0.00 / no parsed evidence / —` for genuine survivors. Root cause was two-fold and is
now fixed by a normalized **`ea_metrics`** SQLite table that the renderers read from.
The same table also cured a **permanent `p2_pass_no_p3` health FAIL** caused by
Q02→Q03 promotion starvation. The table auto-refreshes (5-min pump + hourly render) and
is now monitored by the `ea_metrics_fresh` health check.

Operate it with:

```powershell
$PY = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe"
cd C:\QM\repo
& $PY tools/strategy_farm/ea_metrics.py build            # incremental (mtime-gated)
& $PY tools/strategy_farm/ea_metrics.py build --full      # full rebuild (recovery)
& $PY tools/strategy_farm/ea_metrics.py show --ea QM5_10440
# or the wrapper:
tools/strategy_farm/rebuild_ea_metrics.ps1                # full rebuild + verify
```

---

## 1. The two problems

### 1a. Empty Strategy Archive
`work_items` stores **no numeric columns** — only `verdict/status/phase/symbol` and an
`evidence_path`. The real numbers live in per-phase evidence JSON whose **shape differs
per gate**. The renderers tried to parse these at render time from
`payload.recovered_stats` (almost always empty) and a `runs[0]` fallback, so they fell
back to `—`. Worse, the headline row per `(phase, symbol)` was the **latest** attempt —
frequently an `INFRA_FAIL` re-run or an **ablation perturbation** (`is_ablation`, net≈0)
— which buried the real PASS run.

Example — **QM5_10440 / NDX** truly is: Q02 +$49,991 net, PF 1.22, 360 trades, DD 14.4%;
Q04 walk-forward all 3 OOS folds PASS (PF 1.12 / 1.77 / 1.19); Q07 PF 1.57 stable across
5 seeds. The page showed none of it.

### 1b. Permanent `p2_pass_no_p3` FAIL (promotion starvation)
`§10c` in `farmctl.py` is the **only** Q02→Q03 promoter (the `cascade_phase_map` loop
starts at Q03→Q04). Its candidate query is *every Q02-PASS without a Q03 sibling*,
`ORDER BY updated_at ASC LIMIT 5000`. ~5,180 of those rows are permanently
**unprofitable** (correctly never promoted) but were never removed, so they saturated the
oldest-first 5,000-row window. The genuinely promotable **profitable** rows are always the
**newest** → forever beyond the window. Measured 2026-06-22: 5,224 candidates, all 47
profitable-promotable rows past the window cutoff → **0/47 promoted every cycle** → the
health check sat at a permanent FAIL even though `farmctl pump` "ran fine".

---

## 2. Architecture — `ea_metrics`

`tools/strategy_farm/ea_metrics.py` reads every `work_items.evidence_path` **once** and
writes a normalized row per work_item into `ea_metrics` in `farm_state.sqlite`.

**Schema** (one row per work_item that has evidence):

| column | meaning |
|---|---|
| `work_item_id` (PK) | FK to `work_items.id` — enables a direct per-row join |
| `ea_id, phase, symbol, verdict, status` | mirrored from work_items |
| `is_ablation, parent_work_item_id` | from `payload_json` — separate perturbations from the canonical run |
| `net_profit, profit_factor, trades, drawdown_money, drawdown_pct, sharpe` | normalized headline scalars (any may be NULL) |
| `detail_json` | phase-specific structure (folds / seeds / sub-gates / portfolio) |
| `source` | which parser branch produced the row (`summary_runs`, `q04_folds`, `q05q06_flat`, `q07_seeds`, `q08_subgates`, `q09_portfolio`, `missing`, `parse_error`, …) |
| `evidence_path, evidence_mtime, extracted_at` | provenance + incremental-build gate |

**Per-phase field map** (the evidence shapes the extractor handles):

| Phase | Evidence file | Headline source | detail_json |
|---|---|---|---|
| Q02/Q03/P2 | `…/summary.json` | best-net `runs[]` entry: `net_profit / profit_factor / total_trades / drawdown (+ _raw → dd%)` | all `runs[]` |
| Q04 | `…/Q04/<SYM>/aggregate.json` | mean `folds[].pf_net`, Σ `trades`, Σ fold net | every fold (oos window, pf_net, trades, status) |
| Q05/Q06 | `…/Q05|Q06/<SYM>/aggregate.json` | flat `pf / trades / dd_money / dd_pct` | `stress_level, rejection_probability` (Q06) |
| Q07 | `…/Q07/<SYM>/aggregate.json` | `metrics.mean_pf`, max per-seed dd% | `metrics` + `per_seed[]` |
| Q08 | `…/Q08/<SYM>/aggregate.json` | `gross_total − commission_total`, `baseline_run.baseline_profit_factor`, `n_trades` | `cost_cushion`, `sub_gates[]`, `verdict_classification` |
| Q09_PORTFOLIO | `…/Q09_PORTFOLIO/<SYM>/aggregate.json` | `standalone_pf`, `trade_count`, `sharpe_with`, `maxdd_with` | with/without sharpe & maxdd, diversifies, admit |

All files are read as `utf-8-sig` (BOM-tolerant). Extraction never raises — a bad file
records a `source` tag and NULL scalars. Full build ≈ 34.6k rows in ~33 s.

---

## 3. Data flow (who reads it)

- **`ea_<id>.html` detail pages** (`collect_ea_detail`): per-row tables read `ea_metrics`
  by `work_item_id` (preferred over empty `recovered_stats`; the legacy
  `_parse_summary_stats` only fills gaps, e.g. the report-htm equity SVG). The **headline
  row per (phase, symbol)** now picks the most representative attempt
  (`non-ablation > graded > PASS > net`), not latest-degenerate. All Q04 folds render.
- **`strategies.html` overview** (`collect_ea_lead_kpis`): `best_net / trades_mean /
  dd_worst` come from `ea_metrics` (ablation rows excluded from "best").
- **`cockpit.html` is deliberately NOT changed.** OWNER IA split: the **Strategy Archive**
  is the strategy archive (per-EA numbers); the **Cockpit** is the company & its progress
  (funnel / throughput / health), no per-EA number tables.
- **`§10c` promoter** (`farmctl.py`): pre-filters Q02→Q03 candidates to
  `ea_metrics.net_profit > 0`, so unprofitable rows never consume the LIMIT window.

---

## 4. Automatic refresh (how it "pulls" on its own)

`ea_metrics.build(con, full=False)` is **incremental** (skips rows whose
`evidence_mtime` is unchanged) and is invoked inline by two already-scheduled jobs — no
new cron, so no extra SQLite write contention:

| Trigger | Task | Cadence | Why |
|---|---|---|---|
| Pump §10c | `QM_StrategyFarm_Pump_5min` | **5 min** | promotion pre-filter needs current numbers (load-bearing) |
| Dashboard render | `QM_StrategyFarm_Dashboard_Hourly` | **hourly** | archive pages render with fresh numbers |

Both call sites are wrapped in `try/except` so a refresh failure never blocks the pump or
the render. Because that makes failure **silent**, the `ea_metrics_fresh` health check
(below) exists to surface staleness.

### Observability — `ea_metrics_fresh`
`chk_ea_metrics_fresh` in `health.py` (runs under `QM_StrategyFarm_Health_15min`):
- `WARN` if the `ea_metrics` table is absent, empty, or `MAX(extracted_at)` is older than
  **90 min** (pump should keep it < 10 min fresh) → the inline refreshers are failing.
- `OK` otherwise, reporting row count and age.

It is WARN-level on purpose: the hard backstop for missed promotions is `p2_pass_no_p3`
(which FAILs), and blank archive numbers are non-fatal. If `ea_metrics_fresh` warns, run a
manual build and check pump logs.

---

## 5. Recovery / operations

```powershell
# Force a clean full rebuild (after a schema change or suspected drift) + verify:
tools/strategy_farm/rebuild_ea_metrics.ps1

# Inspect one EA's normalized rows:
& $PY tools/strategy_farm/ea_metrics.py show --ea QM5_10440
```

A full rebuild is safe and idempotent (upsert keyed by `work_item_id`). The renderers and
the pump degrade gracefully if the table is missing (legacy parse / unfiltered scan), so a
rebuild can be run live.

---

## 6. Caveats

- **net semantics:** `ea_metrics.net_profit` for Q02 is the **best run's** net; the §10c
  in-loop authoritative gate uses the evidence **net-sum**. They differ only for
  mixed-sign multi-run rows (tiny, bounded; the `LIMIT 5000` absorbs them). The pre-filter
  is an optimization; the in-loop evidence gate remains authoritative for what gets
  promoted.
- **ablation rows** carry `result: PASS` in their own summary.json while losing money
  (perturbation runs). `is_ablation` separates them; they are excluded from "best" and
  from the promotion pre-filter sense via the profit gate.
- **freshness gap:** a brand-new Q02-PASS not yet extracted is excluded from the promotion
  pre-filter until the next refresh — covered by the inline refresh at §10c start.

See also memory: `project_qm_ea_metrics_archive_layer_2026-06-22`,
`project_qm_p2p3_promotion_starvation_2026-06-22`.
