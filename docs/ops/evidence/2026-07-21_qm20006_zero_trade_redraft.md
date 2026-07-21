# QM5_20006 (SP500.DWX) Q02 zero-trade draft defect — diagnosis, fix, requeue

Date: 2026-07-21 · Author: Claude (headless) · Class: DRAFT_DEFECT (entry gating
never fires), NOT an edge verdict. FTMO-book density candidate (intraday-flat,
swap-free) — OWNER wants it working.

## 1. Symptom

Q02 work item `1fe24586-9c9b-44ef-ab42-96697753fa98` (QM5_20006 spx-intraday-mom,
SP500.DWX, M30, Model 4): P2 prescreen 2022.07.01–2022.12.31 on T10 →
`run_smoke_fail:MIN_TRADES_NOT_MET`, **0 trades**, PF 0.00. Clean run: INIT OK, no
log bomb, real-ticks marker present, valid report latched.

- Evidence: `D:\QM\reports\work_items\1fe24586-9c9b-44ef-ab42-96697753fa98\QM5_20006\20260720_112250\summary.json`
- Report: `...\raw\run_01\report.htm`, tester.ini window `2022.07.01–2022.12.31`

## 2. Root cause (file:line)

`framework/EAs/QM5_20006_spx-intraday-mom/QM5_20006_spx-intraday-mom.mq5:42` (v1):

```mql5
#define STRATEGY_SCAN_BARS 800   // bounded backward scan depth
```

The entry gate needs `strategy_vol_lookback + 1 = 21` sessions of both 16:30-open
(first-half-hour) and 22:30-open (prev-session-close) M30 anchors, collected by a
backward scan capped at **800 bars**. That cap was sized for a cash-session mental
model (~13 bars/day). **SP500.DWX is a ~23h CFD grid: 46 M30 bars per trading day
(01:00–23:30 broker)** — verified from `D:\QM\mt5\T_Export\MQL5\Files\SP500.DWX_M30.csv`
(bars-per-day histogram mode = 46 across 1,838 trading days, 2018-07→2025-12).

Static replay of the v1 collector against the real bar sequence (same CSV):

- 126 22:30-decision bars in the smoke window → **`CollectSessionShifts` fails on
  126/126**: the 800-bar scan finds only 18/21 required 16:30 anchors and 15–17/21
  22:30 anchors.
- Worst-case depth actually needed: **1,043 bars** (lookback 20); **1,581 bars** at
  the card's sweep max (lookback 30).

So `ComputeRfhSeries` returned false on every session of every year → entry gate
never fired → deterministic 0 trades over any window. Known-defect classes (a)
symbol_slot (set + ZeroMemory'd), (b) news gating (calendar OK, age 7h; tester CSV
path inert), (c) session/broker-time (16:30/22:30 anchors are correct and
DST-invariant under NY-close GMT+2/+3), (e) TF token (M30 fine), (f) symbol
availability (SP500.DWX present on T1–T10, history 2018–2026) were checked and
excluded.

## 3. Fix (v2 draft — minimal, no strategy redesign)

`QM5_20006_spx-intraday-mom.mq5`:

1. **Scan depth** now derived from the requested session count instead of a fixed
   800: `scan_bars = (n_needed + 6) * 64`, hard-capped at
   `STRATEGY_SCAN_BARS_MAX 4096` (need 21 → 1,728 ≥ 1,043; need 31 → 2,368 ≥ 1,581).
   Runs once/day at the 22:30 gate only.
2. **Prev-close pairing**: each 16:30 anchor is paired with the nearest OLDER
   22:30 anchor (two-pointer), so half-days lacking a 22:30 bar can no longer
   desynchronise the r_fh series (v1 paired two independently-collected lists
   index-by-index).
3. **Same-day guard**: today's signal requires today's own 16:30–17:00 bar
   (card §6 short-session skip made explicit — no trading on stale anchors).

SSRN-verified re-draft bindings (`docs/research/SSRN_MINING_2026-07-20.md`, rank 9),
applied to card + EA + set:

4. **Primary variant added — first-half-hour realized-vol conditioning**: new input
   `strategy_fh_vol_mult` (default 1.0, sweep [0.0, 1.0, 1.25]); gate:
   `(High−Low)/Close` of the 16:30 bar ≥ mult × trailing-`strategy_vol_lookback`-session
   median of the same measure. Self-referencing structural condition (Q08
   neighborhood-safe), pre-registered adaptation of Gao 2018's realized-vol tercile
   split (high tercile 14.73%/yr t=3.8 vs low 0.54% dead). `0.0` = unconditional
   control — expected ~dead OOS post-2013 (QuantConnect 2015-2020 Sharpe −0.63);
   per directive it must NOT be tuned back to life if it fails net.
5. **Mechanism attribution** on the card moved to gamma-hedging demand
   (Baltussen, Da, Lammers & Martens 2021, JFE, SSRN 3760365); prose citation with
   year + DOI added for the validator (Gao, Han, Li & Zhou (2018), JFE 129(2),
   394-414, https://doi.org/10.1016/j.jfineco.2018.05.009).
6. **Honest density**: declared frequency corrected 185 → **75/yr** (static replay
   with both filters at defaults: 34 entries 2022H2, 78 entries 2024; the two
   filters overlap on high-vol days).

Static validation of the v2 logic against the same bar sequence: series builds on
**100/100** Friday-skipped decision bars in the smoke window (vs 0/126 in v1);
34 entries ≥ `effective_min_trades=5`.

Files changed (committed atomically):

- `framework/EAs/QM5_20006_spx-intraday-mom/QM5_20006_spx-intraday-mom.mq5`
- `framework/EAs/QM5_20006_spx-intraday-mom/QM5_20006_spx-intraday-mom.ex5`
- `framework/EAs/QM5_20006_spx-intraday-mom/sets/QM5_20006_spx-intraday-mom_SP500.DWX_M30_backtest.set`
  (append `strategy_fh_vol_mult=1.0`, set_version `s20260721-002`, build_hash restamped)
- `artifacts/cards_approved/QM5_20006_spx-intraday-mom.md` (synced to
  `D:\QM\strategy_farm\artifacts\cards_approved\` — diff-verified identical)

## 4. Compile

`build_check.ps1 -Strict -EALabel QM5_20006_spx-intraday-mom` (drives
`compile_one.ps1`, serial): **PASS** — 0 errors, 0 warnings, perf lint clean,
set validation PASS, build_hash restamped `905ebf2c…`.
Report: `D:\QM\reports\framework\21\build_check_20260721_044300.json`;
compile summary `D:\QM\reports\compile\20260721_044300\summary.csv`.

## 5. Requeue (staged recovery)

Work item `1fe24586-9c9b-44ef-ab42-96697753fa98` flipped `done/FAIL → pending`:
verdict/evidence/claim cleared, attempt_count 0, run-state payload keys
(p2_prescreen_*, claim/pid/terminal/verdict_*) stripped,
`requeue_reason=zero_trade_draft_defect_scan_depth_fix_v2`,
`priority_track=true` (H-A semantics for force_build/new-EA Q02),
`expected_trades_per_year_per_symbol=75`, requeued_at 2026-07-21T04:44:25Z.
Precedent: 2026-07-20 overnight staged recovery (20004) + qm5_10134 repair.

## 6. Flags for coordinator

- **ea_id collision**: `D:\QM\strategy_farm\artifacts\cards_review\QM5_20006_london-fix-reversion.md`
  (g0 REVIEW) claims `ea_id: QM5_20006`, which is owned by the approved
  spx-intraday-mom card. Duplicate-dispatch hazard class (memory 07-05/07-14) —
  that card needs a fresh ea_id before approval.
- Lesson (card §16): size session-anchor scans from the symbol's OBSERVED bar
  density, never from the cash-session mental model. Generalizes to every
  intraday index EA on ~23h .DWX CFD grids.
