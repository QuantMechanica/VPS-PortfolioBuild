---
ea_id: QM5_1088
slug: aa-faa-ravc
artifact_type: zero_trade_rework_critique
trigger: DL-062_zero_trade_rework_trigger
router_task_id: 7ef56f93-c0e2-4923-a82a-bd0e91506a2e
parent_card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_1088_aa-faa-ravc.md
author: claude
written_at: 2026-05-23
verdict: REWORK_FALSE_POSITIVE_ARCHITECTURE_INCOMPATIBLE_PARK_UNTIL_BASKET_HARNESS_OR_RECAST
---

# QM5_1088 aa-faa-ravc — zero-trade rework critique

Router fired DL-062 on `completed=37 / fail=34 / zero_trade=30 (zt_pct=0.88)`. After
reading the card, sampling work_items evidence, and inspecting setfile + summary.json,
the dominant failure mode is **not strategy mortality**. It is the same architectural
mismatch as [[QM5_1048]] (Estrada lazy 6-month rotation) layered on top of the
known [[dispatcher universe-mismatch]] bug.

## 1. Evidence sample (work_items, latest first)

| run                  | symbol      | phase | period | min_trades | result  | notes                |
|----------------------|-------------|-------|--------|------------|---------|----------------------|
| 2026-05-18 14:09Z    | 30× FX/CFD  | P2    | H1     | 3          | FAIL    | full DWX fan-out     |
| 2026-05-18 14:09Z    | EURUSD.DWX  | P2    | H1     | 36         | FAIL    | in-universe          |
| 2026-05-18 14:09Z    | NDX.DWX     | P2    | H1     | 36         | FAIL    | in-universe          |
| 2026-05-18 14:09Z    | USDJPY.DWX  | P2    | H1     | 36         | failed  | INVALID/incomplete   |
| 2026-05-18 14:09Z    | GDAXI.DWX   | P2    | H1     | 36         | failed  | INVALID/incomplete   |
| 2026-05-18 14:09Z    | SP500.DWX   | P2    | H1     | 36         | failed  | INVALID              |
| 2026-05-18 14:09Z    | XAUUSD.DWX  | P2    | H1     | 36         | failed  | INVALID              |
| 2026-05-18 14:09Z    | XTIUSD.DWX  | P2    | H1     | 36         | failed  | INVALID              |

Symbol histogram: 36 unique DWX symbols, ~1 P2 row each. Card declares a 7-symbol
cross-asset proxy universe; ~83% of the runs are outside that universe.

## 2. Three independent root causes — none of them is "the edge is dead"

### 2a. Cross-sectional rotation strategy run per-symbol (architecture)

FAA RAVC is, by construction, a **portfolio composite-rank rotation**: every month,
compute relative-momentum + vol-rank + correlation-rank across the 7-asset
universe, gate by absolute momentum, and equal-weight the top-3. The decision for
asset `A` depends on the rank distribution of all other assets, which the V5 P2
harness cannot supply: each work_item is a single-symbol backtest.

Per-symbol execution collapses the strategy to "did this single asset's absolute
momentum stay positive?" — the rank-based selection mechanism has nothing to
choose against. With the absolute-momentum cash gate as the only remaining
filter, expected entries per asset per year drop from ~3 (top-3 of 7, monthly)
to noise around the bull/bear regime line. That gives the zero-trade
fingerprint, not a defective edge.

This is the **same architectural incompatibility** flagged for QM5_1048 in
`docs/research/rework_critique_QM5_1048_2026-05-23.md` (commit `af0cc69a`):
V5 P2 has no portfolio-coordination primitive, so cross-sectional rotation
strategies cannot be tested against it.

### 2b. Dispatcher universe mismatch (scope)

Card `target_symbols` (implicit in the §R3 section) is the 7-asset proxy:
`SP500.DWX, NDX.DWX, GDAXI.DWX, XAUUSD.DWX, XTIUSD.DWX, EURUSD.DWX, USDJPY.DWX`.
P2 enqueue fanned across 36 DWX symbols including FX crosses (AUDCAD, AUDCHF,
…, NZDJPY) and minor indices (UK100, WS30). 30/37 work_items are out-of-universe.

This is the documented dispatcher universe-mismatch failure
(memory `project_qm_dispatcher_universe_mismatch_2026-05-23`): the work_items
dispatcher ignores `card.target_symbols` for universe-locked EAs and inflates
the zero-trade ratio. Triage-in-universe-first is the standing instruction.

### 2c. Timeframe mismatch — monthly strategy run on H1 with min_trades=36

The card mechanic is explicit: "Monthly at the close" — `expected_trades_per_year_per_symbol: 12`
implies one rebalance per month per leg. P2 ran every in-universe symbol on
**H1** with **min_trades_required=36** over a **1-year** window. That is structurally
impossible: a strictly-monthly rebalance produces at most 12 candidate entries
per leg per year, gated by the cash-eligibility rule (~50–60% pass-through),
so realistic max is 6–8 trades/year/leg. min_trades=36/yr cannot be met by
the strategy's own rules regardless of edge quality.

Also: the H1 candle granularity has no semantic relationship to "monthly close"
— there is no way for a monthly-rank rebalancer to fire on an H1 bar except
via accidental month-rollover candle alignment.

The OS-incomplete runs (SP500/XAUUSD/XTIUSD/GDAXI 4× `INVALID`) are a separate
build/H1-data issue but they are not zero-trade evidence either.

## 3. Why the DL-062 trigger fired

`_is_zero_trade_failure_payload` correctly excludes `NO_HISTORY/INVALID_REPORT`
but does not know:
- whether the symbol is inside the card's authorized universe (2a);
- whether the strategy's own cadence can satisfy the harness's `min_trades_required`
  (2c);
- whether the strategy is cross-sectional and therefore harness-incompatible (2a).

For universe-locked, monthly, portfolio-coordinated EAs, the trigger guarantees
~90% spurious zero-trade attribution. **This DL-062 fire is a false positive
driven by scope + timeframe + harness architecture — not by strategy degeneracy.**

## 4. Recommended change vector

Reject the router hint to relax entry conditions or substitute signal logic.
The card faithfully implements Wesley Gray's published rules; relaxing the
composite-rank or absolute-momentum gate would be in-sample tuning the
pipeline exists to prevent. Required actions, in order:

1. **Mark architecture-blocked, NOT DEAD.** Annotate the card with
   `pipeline_phase: BLOCKED_ARCHITECTURE_INCOMPATIBLE` and a pointer to this
   critique. Do not re-enqueue on V5 P2 in current form.

2. **Choice (a) — wait**: park until the basket-EA harness lands (per
   `project_qm_basket_ea_build_2026-05-22`, QM5_10717 is the V5 reference
   single-host basket EA). Once available, rebuild as a single-host basket-EA
   carrying all 7 proxy legs with a portfolio-rank module.

3. **Choice (b) — recast**: write a NEW card derived from QM5_1088 that
   implements absolute-momentum-only per leg (single-symbol harness-compatible)
   on the SP500/NDX/GDAXI/XAUUSD/XTIUSD/EURUSD/USDJPY universe at D1 with
   monthly evaluation. Tag in front-matter `derived_from: QM5_1088`. This is
   a strict subset of the original mechanic and will lose the composite-rank
   edge — call it out in the card.

4. **Ops (codex)**: same enqueue-scope fix needed for QM5_1048 / QM5_10020 /
   QM5_1044 applies here. Honor `target_symbols` from the card front-matter.
   This is a shared root cause across all four recent DL-062 false positives.

5. **Edge Lab compliance**: card pre-dates the 2026-05-22 charter. Either
   recast path must include the FTMO-compliance block (≤5% daily / ≤10% total
   DD, news-blackout, no martingale/grid, mechanical, no-ML). Current card
   has no DD spec and no news-filter spec.

## 5. Falsification — when this critique becomes wrong

If, after the basket-EA harness lands and QM5_1088 is rebuilt as a single-host
basket EA against the 7-asset proxy universe at D1 monthly rebalance, the EA
still produces 0 trades over a ≥5y backtest with the unaltered Alpha-Architect
rules, then the critique is wrong and the rank/cash-gate combination has
become structurally inactive on the DWX proxy basket (likely the absolute
momentum gate routing everything to cash). That would be a legitimate kill
verdict — current evidence does not yet support it.

## 6. Verification I ran

- Card at `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1088_aa-faa-ravc.md`
  — confirmed 7-asset proxy universe, monthly rebalance, top-3 cash-gated rank.
- Direct sqlite query against `D:\QM\strategy_farm\state\farm_state.sqlite`
  (work_items, ea_id=QM5_1088): 37 P2 rows, 36 unique symbols, all H1, all
  bulk-enqueued 2026-05-18 14:09Z.
- Sampled `summary.json` for 4 out-of-universe (AUDCAD/AUDCHF/AUDJPY/AUDNZD)
  + 7 in-universe runs: period=H1, year=2024, min_trades_required={3,36}
  depending on enqueue batch, model=4.
- Cross-referenced `tools/strategy_farm/farmctl.py` classifier behavior with
  prior critiques (commit `af0cc69a`) for QM5_10020 / QM5_1044 / QM5_1048 —
  same DL-062 false-positive class.
- Memory: `project_qm_dispatcher_universe_mismatch_2026-05-23`,
  `project_qm_basket_ea_build_2026-05-22`.
