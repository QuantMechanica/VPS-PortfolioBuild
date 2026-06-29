---
ea_id: QM5_12785
slug: timerangebreakout-orb
type: strategy
source_id: owner-timerangebreakout-vers38-2025
sources:
  - "[[sources/owner-timerangebreakout]]"
  - "[[sources/orchard-forex-time-range-breakout-2022]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/session-breakout]]"
  - "[[concepts/eod-flat-no-swap]]"
indicators:
  - "[[indicators/opening-range]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "OWNER's own developed EA (Fabian Grabner 2025), 38-version lineage off the Orchard Forex 2022 base, with extensive author backtests (Hyonix collection: ~112 reports, indices/gold/FX). OWNER-sourced + battle-iterated. (R1-R4 waived for discovery; this is OWNER's own code.)"
r2_mechanical: PASS
r2_reasoning: "Deterministic daily opening-range breakout: range = H/L over a fixed clock window (08:00-12:00) from M1; buy-stop above range high / sell-stop below range low after window close; hard SL = range width; TP = %-of-range; flat at daily close + Friday close. One entry per side per day. No discretion. Verified by source teardown."
r3_data_available: PASS
r3_reasoning: ".DWX intraday history for indices/gold; asset-agnostic price-range logic."
r4_ml_forbidden: PASS
r4_reasoning: "No ML. Grid-vs-clean teardown CONFIRMED CLEAN: fixed-fractional lots (no loss-scaling), no averaging-down (adds only into winners, decreasing 0.6^n size, each stop-protected = positive pyramiding, the opposite of martingale), every order carries a hard SL. EOD-flat = no swap/overnight. Port disables pyramiding -> single-position-per-magic."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 120
expected_pf: 1.40
expected_dd_pct: 10
last_updated: 2026-06-29
g0_approval_reasoning: "G0 2026-06-29 Claude. CROWN JEWEL of the Hyonix 5-agent audit: OWNER's OWN TimeRangeBreakout (vers38) is a clean, stop-protected intraday opening-range breakout, EOD-flat (no swap), asset-agnostic - i.e. EXACTLY the higher-frequency-on-low-commission intraday lane the 4-agent intraday-scoping concluded we need (matches the ORB lane + GER40/US100/XAUUSD substrate + 15-30min sweet spot). Agent-A grid-vs-clean verdict: CLEAN (not martingale/grid; pyramiding is decreasing-size-into-winners = positive). Agent-B backtests: strong GROSS PF on indices (US100 ~2.0-2.3, GER40 2.21, US30 2.08, XAUUSD high but verify) - but ALL gross-of-cost; FX-cross configs (EURNZD 6.05 etc.) die net at M15 cadence on ~$45/RT commission (our cost model), so target INDEX/GOLD only. This is a ready-made, owner-validated realization of the ORB lane -> port directly instead of building it from scratch (complements the QM5_12784 configurable engine, which still builds the momentum-band + gold-vol-contraction lanes). Decisive gates: Q04 net-of-cost (the gross backtests' real test) + Q08 PBO/DSR."
---

# TimeRangeBreakout ORB (OWNER vers38 -> V5 port)

## Purpose
Port OWNER's own clean intraday opening-range breakout (TimeRangeBreakout vers38) into the V5
framework as the lead intraday-breakout sleeve. It is the ready-made, author-validated ORB lane:
higher-frequency, EOD-flat (no swap), asset-agnostic -> aim at low-commission indices/gold where
the breakout's gross approx net and the FX ~$45/RT commission wall disappears.

## Source
`C:/Users/Administrator/Downloads/Hyonix/Hyonix/TimeRangeBreakout_vers38.mq5` (final core;
entry/SL L2034-2153, lots L1908, pyramiding L2514-3122). Cleanest modular skeleton:
`TimeRangeBreakout.mq5` v1.00 + `Core/` (TradeManagement/Filters/Patterns/TimeManagement). Genesis:
`Time Range Breakout.mq5/.mqh` (Orchard 2022). Clean single-position sibling: `DailyRangeBreakout_1.mq5`.

## Strategy (build spec)
- **Range:** H/L over a fixed clock window (default RangeStartHour=08:00, RangeDuration=240min ->
  08:00-12:00 broker time) built from M1 bars.
- **Entry:** after window close, buy-stop at rangeHigh + InpOrderDistance%, sell-stop at rangeLow -
  InpOrderDistance% (breakout). One entry per side per day (latched).
- **Stop:** hard SL = entry -/+ rangeSize x InpStopLoss% (default 100% of range width).
- **Target:** fixed TP = entry +/- rangeSize x InpTakeProfit%. **Port sets InpTakeProfit=150-180%**
  (R:R ~1.5-1.8) so the edge is a bounded R-multiple the gates can score (NOT trail-only/EOD-only).
- **Exit:** force-flat at InpCloseHour (~21:50) + Friday close -> flat overnight/weekend, no swap.
- **Filters (optional, default off):** MT5-calendar news blackout; min/max range-size (pips) +
  spread cap; (skip the MA/Ichimoku/pattern packs for the first port - keep it lean).

## Required changes for V5 (from the source teardown)
1. **Pyramiding OFF** (`InpUsePyramiding=false`, MaxPyramidLevels=1, never Cascade/TrailType=3) ->
   single-position-per-magic (V5 framework). (Pyramiding is clean but breaks single-position; defer.)
2. **Fixed TP ON** (150-180% range) instead of trail-only.
3. **Magic** -> V5 registry formula ea_id*10000+slot (replace hardcoded 20687).
4. **Symbol routing** -> run on the current chart symbol per our per-symbol slot model (drop the
   Dukascopy `*DUKA` symbol-enum / GetSymbolFromEnum indirection).
5. Wire V5 includes: QM_RiskSizer (RISK_FIXED backtest / RISK_PERCENT live), QM_KillSwitch (3% daily
   breaker already standard), QM_NewsFilter (DL-080 native calendar), QM_MagicResolver, QM_Logger.
6. Costs injected at Q04/Q08 (author backtests + .DWX = $0; must be costed).

## Instruments + OWNER's tuned per-symbol session windows
Low-commission lead (gross approx net): **US100, US500, SP500, GER40, XAUUSD**. PLUS **JPY pairs
(OWNER-directed 2026-06-29):** **USDJPY, EURJPY, AUDJPY, CADJPY, GBPJPY, NZDJPY** — FX/high-commission
BUT this breakout is LOW-cadence (~1 entry/side/day, not M15-scalp) so it is cost-tolerant like the
calendar anomalies; Q04 net-of-cost is the judge. (FX majors EURUSD/GBPUSD: lower gross + cost-heavy
-> defer.)

**OWNER's tuned QuantRangePRO session windows** (harvested from his Hyonix RANGE set files; use these
to generate the V5 per-symbol backtest sets. All InpStopLoss=100% of range; original TP=0/trail+EOD ->
PORT adds a fixed TP ~150-180% too so the gate can score it):

| Symbol | Range start | Duration | Close | Risk% | Range-gate |
|---|---|---|---|---|---|
| US100  | 11:50 | 220min | 21:50 | 0.5 | - |
| US500  | 10:55 | 250min | 17:00 | 1.0 | - |
| SP500 (long-only) | 08:35 | 375min | 19:00 | 0.5 | - |
| GER40  | 01:20 | 510min (overnight -> DAX open) | 18:15 | 0.5 | - |
| XAUUSD | 03:05 (Asian) OR 11:50 (London) | 180/220 | 18:55/21:50 | 0.5 | 1-5 |
| USDJPY | 03:00 (Asian) | 180min | 18:00 | 0.5 | 5-250 |
| EURJPY | 08:00 (London) | 75min | 21:00 | 0.2 | 5-100 |
| AUDJPY | 03:00 (Asian) | 345min | 18:00 | 0.5 | - |
| CADJPY | 04:50 | 505min | 23:00 | 0.5 | - |
| GBPJPY, NZDJPY | variants in Breakout5-7 | - | - | - | - |

Times = OWNER's broker time; map to .DWX/our broker time at build. Source sets:
`Hyonix/Hyonix/Breakout3/SetfilesRANGE/` (NEWUS100, NEWXAUUSD, XAUUSD_Special, USDJPY2, _AUDJPY/_CADJPY)
+ `Breakout2`/`Breakout3` per-symbol .set + `Breakout4-7` (JPY iterations). Pattern: Asian-window for
gold/JPY/AUD, late-morning for indices, overnight-into-open for DAX, London-open for EURJPY.

## Time-parameter optimization (overfit-guarded sweep, OWNER-directed)
OWNER's hand-tuned windows are the SEED, not the answer — systematically sweep the session
parameters, but OVERFIT-GUARDED (naive optimize-and-trust is exactly what we ban; EA-PAAT did that
and went underwater with real money). Principles:
- **Optimize the SESSION, not the minute.** RangeStartHour on a COARSE ~hourly grid over the
  instrument's plausible active hours; RangeDuration in coarse steps {60,120,180,240,360,480}; do
  NOT sweep 5-min RangeStartMin (that's curve-fitting). Session windows have ECONOMIC justification
  (liquidity/vol concentrates by session: DAX open, Asian gold/JPY, London EURJPY) -> optimizing the
  window finds the real active session, not noise. Coarse + economically-grounded = low overfit surface.
- **Per-symbol grid** seeded around OWNER's tuned window (+/- a few hours / duration steps), ~20-40
  configs/symbol, generated as backtest set files post-build (like our existing _grid_NNN sets).
- **The pipeline IS the overfit guard:** every config runs Q04 (walk-forward net-of-cost — selects on
  OOS folds, not in-sample) + Q08 **PBO/DSR** (Probability-of-Backtest-Overfit / Deflated Sharpe —
  explicitly deflates for the NUMBER of configs tried). We do NOT pick the best full-history PF; the
  gates select the robust window AND penalize the multiple-testing. Same coarse-time-sweep applies to
  12787 (vol-contraction) and the 12784 engine.
Post-build step: generate the coarse per-symbol time-grid sets and enqueue; PBO/DSR handles the
selection bias. Hand-tuned window also enqueued as one config (the seed) for comparison.

## Acceptance
Q02 gross + intraday trade floor -> the DECISIVE Q04 net-of-cost walk-forward (the real test of the
gross author backtests) -> Q08 PBO/DSR (overfit defense; the family has many tuned variants) -> hot-VaR.
Realistic bar: ~1.0-1.4 standalone PASS; combine with other intraday sleeves for book Sharpe >1.5.
Successor note: the family's frontier is "QuantRangeVOLA" (volatility-contraction range instead of a
fixed clock) - if it clears, evaluate that variant next (overlaps the QM5_12784 gold-vol-contraction lane).
