# Q08 Portfolio-Rescue Track — Implementation Plan (2026-06-03)

## Decision (OWNER)
Q08 (Davey suite) stays **HARD as the standalone / live gate** — no loosening for live
admission. But Q08 fails that are about *sample size* or *single weaknesses* must NOT be
final-killed; they route to a **portfolio-candidate track** where the question changes from
"is this robust standalone?" to "does this *improve the portfolio* despite its weakness?"
A negative month after a Q04 walk-forward must not disqualify an EA from the portfolio.

## Grounded architecture (verified in code)
- **Q08 runner:** `framework/scripts/q08_davey/aggregate.py`, 10 AND-combined sub-gates
  (8.1 correlation, 8.2 DSR/FDR, 8.3 tail, 8.4 seasonal, 8.5 neighborhood, 8.6 chopping
  block, 8.7 PBO, 8.8 edge decay, 8.9 runs, 8.10 regime/crisis). Emits `verdict` +
  per-sub-gate `status`+`detail` to `aggregate.json`.
- **Portfolio layer ALREADY EXISTS (DL-064):** `tools/strategy_farm/portfolio/portfolio_admission.evaluate_candidate()`
  computes correlation-to-book, Sharpe with/without, maxDD with/without, `diversifies`.
  Trade streams come from `Common/Files/QM/q08_trades/<ea>_<sym>.jsonl` (per-trade net,
  cost, timestamp). **The portfolio contribution test is mostly WIRING this, not new math.**
- **Routing:** `farmctl.py` cascade: Q07→Q08→Q10 on PASS only; Q08 FAIL dead-ends today.
- **Verdict bug to fix:** `_derive_phase_runner_verdict()` collapses Q08 INVALID→FAIL
  inappropriately (it lists P4/P5 phases, not Q08) — must distinguish.

## Verdict taxonomy (3 tiers, replaces binary PASS/FAIL)
| Verdict | Meaning | Routes to | Final? |
|---|---|---|---|
| `PASS` | all 10 sub-gates pass | Q10 (live track) | – |
| `FAIL_HARD` | real edge failure (see HARD below) | dead-end / OWNER reject | ✅ final |
| `FAIL_SOFT` | low-sample OR isolated weakness, plausible edge | **Q09_PORTFOLIO** test | ❌ rescuable |
| `INVALID` | true infra gap (runner error, missing stream) | re-run | – |

(Keep legacy `FAIL` accepted for back-compat; new runs emit the split.)

## Sub-gate → tier classification — CALIBRATION LOCKED (OWNER "moderate" 2026-06-03)
Locked constants: `N_SEASON=3`, `CHOP_SOFT=0.90`, `PBO_HARD=55`, `MIN_PORTFOLIO_TRADES=30`.

**SOFT (→ portfolio-review):**
- Any `insufficient_trade_count` / `insufficient_daily_returns` / `insufficient_month_coverage`
  / `months_with_no_trades` / `no_trades` / `regime_input_missing` (8.2/8.4/8.6/8.8/8.9/8.10).
- 8.4 seasonal `losing_months` with **count ≤ N_SEASON** (proposed N_SEASON=3).
- 8.6 chopping `pf_after_top5pct_removal` in **[CHOP_SOFT, 1.0)** (proposed CHOP_SOFT=0.90).
- 8.7 PBO in **(40%, PBO_HARD]** (proposed PBO_HARD=55%).

**HARD (final FAIL):**
- 8.2 DSR p ≥ 0.05 (no statistically real Sharpe) — *with sufficient sample*.
- 8.6 chopping pf < CHOP_SOFT (edge lives in <5% of trades).
- 8.7 PBO > PBO_HARD (severe overfitting).
- 8.5 neighborhood breaches (param-unstable), 8.8 edge decay, 8.10 regime loses money,
  8.1 correlation, 8.3 tail.
- 8.4 seasonal losing_months count > N_SEASON.
- PF < 1.0 net-of-cost over the OOS window.

**Guard:** an EA needs a MIN_PORTFOLIO_TRADES (proposed 30) to enter the portfolio test —
a 0-trade EA has no portfolio value either; below that it's `FAIL_SOFT` but parked as
`NEED_MORE_DATA`, not portfolio-tested.

## New gate: Q09_PORTFOLIO (contribution test)
For `FAIL_SOFT` EAs with ≥ MIN_PORTFOLIO_TRADES, run `portfolio_admission.evaluate_candidate()`
against the current passed/candidate book:
- `PASS_PORTFOLIO` if: corr-to-book ≤ max_corr (0.30) AND diversifies (improves Sharpe OR
  reduces maxDD) AND PF>1.0 net-of-cost AND no regime catastrophe → enters
  `portfolio_candidates` (state Q12_REVIEW_READY, flag `portfolio-only`).
- `FAIL_PORTFOLIO` otherwise → final.

## Data: available vs to-add
- ✅ per-trade net/cost/timestamp, daily P&L, correlation, Sharpe, maxDD (portfolio layer).
- ➕ to add: monthly-return breakdown + per-symbol equity curve (cheap aggregations from
  the q08_trades stream) for the seasonal/regime portfolio view + dashboard.

## Phased plan
1. **Taxonomy + classifier (foundation).** `aggregate.py`: add `_classify_fail()` + emit
   `verdict` ∈ {PASS, FAIL_HARD, FAIL_SOFT, INVALID} + `verdict_classification` (per-gate
   tier). Fix the Q08 INVALID→FAIL collapse in `_derive_phase_runner_verdict()`. Expand the
   work_items verdict set + `test_verdict_taxonomy_ws2.py`. *(Codex; low risk, reversible.)*
2. **Q09_PORTFOLIO gate.** New `portfolio/portfolio_q08_contribution.py` wrapping
   `evaluate_candidate()`; monthly/equity aggregation helper. *(Codex; reuses DL-064.)*
3. **Routing.** `farmctl.py` cascade: Q08 FAIL_SOFT (≥min trades) → enqueue Q09_PORTFOLIO;
   PASS_PORTFOLIO → portfolio_candidates; FAIL_HARD/FAIL_PORTFOLIO → final. *(Codex.)*
4. **Dashboard.** Cockpit: standalone-fail reason, portfolio-candidate status, marginal
   Sharpe/DD contribution, "portfolio-only vs standalone" flag. *(Codex + Claude IA.)*
5. **Backfill + verify.** Re-classify the existing Q08 fails; confirm the 3 low-sample +
   QM5_10692 land in the portfolio track, the PBO-88%/PF<1 ones stay final. *(Claude verify.)*

## Re-examination of current Q08 EAs (2026-06-03)
6 distinct EAs / 20 work_items. **LOW_SAMPLE (→ soft):** QM5_10069 (3 tr), QM5_10440 (0),
QM5_10513 (0). **EDGE:** QM5_10260 (PBO 51.4% — borderline), QM5_10627 (PBO 88.6% — hard),
QM5_10692 (443 tr; seasonal 4 months + chopping pf 0.990 — the key SOFT-edge candidate).
Under the proposed calibration: 10069/10440/10513 → FAIL_SOFT (but <30 trades → NEED_MORE_DATA),
10692 → FAIL_SOFT → Q09_PORTFOLIO, 10627 → FAIL_HARD, 10260 → FAIL_HARD (PBO>40, neighborhood).
