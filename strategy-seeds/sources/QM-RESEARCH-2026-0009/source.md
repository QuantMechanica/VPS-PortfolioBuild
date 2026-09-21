---
source_id: QM-RESEARCH-2026-0009
title: London-open range/reversal on EURUSD/GBPUSD (H-V1, native 08:00 Europe/London session structure) — revision 2
source_type: internal_research
source_author: Claude
source_model: claude-fable-5-1
created: 2026-09-21
originating_task_id: 31012467-dde7-4b74-995c-def2241b28c0
status: draft
parent_source_ids: []
source_artifact: QM-RESEARCH://2026-0009
---

# London-open range/reversal on EURUSD/GBPUSD (H-V1, native 08:00 Europe/London session structure) — revision 2

## Research provenance

Revision 1 was authored by Claude (claude-sonnet-5) under task `31012467-dde7-4b74-995c-def2241b28c0`
(routed by Fable) against the frozen 2026-09-20 Velocity evidence cohort. Revision 2 (2026-09-21, Fable /
claude-fable-5-1, same task lineage) answers the cross-vendor critique `1614737c` verbatim in
`docs/ops/evidence/2026-09-20_velocity_book/hv1_hv3_critique_1614737c.md` and replaces every prior by a
measurement. No ML/statistical search instrument was used. All figures come from two deterministic
computed outputs sealed next to this file:

- `baseline_extract.json` — frozen Q02-screen / README figures (13213 template, 41484 fan-out), produced by
  `tools/strategy_farm/session_tools/velocity_hv1_hv3_baseline_extract_20260921.py`;
- `prescreen_extract.json` — the closed-bar M1 prescreen of THIS mechanism on the factory's own `.DWX` custom
  history (EURUSD.DWX, GBPUSD.DWX, 2018-07-02..2025-12-31, 0 factory hours), produced by
  `tools/strategy_farm/session_tools/velocity_hv_prescreen_0921.py` over
  `tools/strategy_farm/session_tools/hcc_m1_reader_0921.py` (reader validated bar-for-bar against the
  terminal's own `QM_M1_SpreadHarvest` JSONL export: EURUSD 94,574 / 94,575 rows identical, GBPUSD
  100,000 / 100,000).

## Prescreen outcome (read this first)

**Indicative closed-bar simulation, commission-only, `.DWX` spread = 0; Q02 would have to confirm — but the
hypothesis is FALSIFIED by its own criteria on the selection period, so no Q02 canary is requested.**

| symbol | period (bd) | arm | trades | trades/bd | E[R] net | PF | worst-year DD (R) | R/bd |
|---|---|---|---|---|---|---|---|---|
| EURUSD | SEL 2018-07..2022-12 (1175) | A15 B+F | 932 | 0.79 | −0.054 | 0.91 | 36.5 | −0.043 |
| EURUSD | SEL | A15 B only | 491 | 0.42 | −0.109 | 0.83 | 30.9 | −0.045 |
| EURUSD | SEL | A15 F only | 441 | 0.38 | +0.007 | 1.01 | 32.8 | +0.003 |
| EURUSD | SEL | A20 B+F | 932 | 0.79 | −0.070 | 0.90 | 53.5 | −0.055 |
| EURUSD | VAL 2023..2025 (783) | A15 B+F | 626 | 0.80 | +0.022 | 1.04 | 30.9 | +0.018 |
| EURUSD | VAL | A15 B only | 327 | 0.42 | +0.169 | 1.33 | 10.6 | +0.071 |
| EURUSD | VAL | A15 F only | 299 | 0.38 | −0.138 | 0.79 | 35.4 | −0.053 |
| GBPUSD | SEL (1175) | A15 B+F | 935 | 0.80 | −0.068 | 0.89 | 50.0 | −0.054 |
| GBPUSD | SEL | A15 B only | 511 | 0.43 | −0.057 | 0.91 | 22.0 | −0.025 |
| GBPUSD | SEL | A15 F only | 424 | 0.36 | −0.082 | 0.87 | 34.8 | −0.030 |
| GBPUSD | SEL | A20 B+F | 935 | 0.80 | −0.075 | 0.89 | 58.7 | −0.060 |
| GBPUSD | VAL (783) | A15 B+F | 589 | 0.75 | +0.058 | 1.11 | 19.5 | +0.044 |
| GBPUSD | VAL | A15 B only | 300 | 0.38 | +0.052 | 1.09 | 12.8 | +0.020 |
| GBPUSD | VAL | A15 F only | 289 | 0.37 | +0.065 | 1.12 | 12.7 | +0.024 |

Per-year net R (A15 B+F): EURUSD 2018 +4.8, 2019 −20.9, 2020 −27.0, 2021 −28.1, 2022 +20.8, 2023 −16.0,
2024 +59.5, 2025 −29.5; GBPUSD 2018 +25.0, 2019 +1.7, 2020 −30.2, 2021 −48.5, 2022 −11.5, 2023 +16.2,
2024 −2.2, 2025 +20.3. Over the full 2018-07..2025 span the combined arm nets −0.023R/trade (EURUSD) and
−0.019R/trade (GBPUSD). The only positive cell, EURUSD breakout-only 2023-25 (+0.169R, driven by 2024
+55.6R), is preceded by −0.109R on the same arm in 2018-22 and is the regime flip the census holdout
(`census_frontier_holdout.json`) already warned about — it is not a selectable edge.

**Why the mechanism cannot carry cost:** the 07:00-08:00 London range is thin (median 14.5 pips EURUSD,
22.1 pips GBPUSD). With the stop equal to the range width, RISK_FIXED 1000 sizes ~6.9 lots (EURUSD) and the
registry commission alone (`framework/registry/live_commission.json`: max(0.005 % notional, 5 USD/lot) round
trip) costs a median **0.040R per trade on EURUSD (p90 0.065R) and 0.031R on GBPUSD (p90 0.050R)** — before
spread, which the `.DWX` history does not carry (evidence GAP for these symbols: no FTMO/DXZ FX spread harvest
exists). A one-signal-per-day mechanism whose gross expectancy is within ±0.05R of zero cannot survive
0.03-0.04R of commission plus an unmeasured London-open spread.

**Disposition recommended to Fable: RETIRE (no card, no build, no factory rows)** unless the round-2 critic
finds a defect in the prescreen simulator (anchor mapping, closed-bar contract, cost model) that would flip
the selection-period sign. The reusable deliverable of this revision is the measurement harness itself
(hcc reader + prescreen, 27 s per hypothesis, 0 factory hours).

## Structural cause (unchanged thesis, restated)

EURUSD and GBPUSD derive their liquidity and directional information from the London session, not Tokyo.
The identical Balke Tokyo-range trigger transplanted onto them measured −0.082R / −0.015R (QM5_41484
fan-out, `baseline_extract.json`), while the USDJPY control reproduced the parent (+0.053R). H-V1 asked
whether the same mechanism class — a bounded opening-range breakout plus a mutually exclusive
failed-breakout reversal — re-anchored to each symbol's own cash open reproduces a session-flat profile of
the 13213 kind (0.74 trades/bd, +0.064R, 0 % overnight). The prescreen answers: density yes (0.75-0.80
trades/bd), expectancy no.

## Mechanical spec — revision 2 (frozen, buildable from this section alone)

- **Symbols:** EURUSD, GBPUSD (one EA identity, one magic slot per symbol; chart symbol drives the strategy).
- **Timeframes:** M15 signal bars, H1 for ATR(14).
- **Anchor mapping (deterministic, DST-aware):** economic anchor = 08:00 Europe/London (cash open). For each
  calendar date the EA/tester computes the broker-time anchor as `toServer(08:00 Europe/London)` where
  `toServer(x) = x expressed in America/New_York local time + 7 h` (Darwinex NY-close server clock: GMT+2
  when US DST is off, GMT+3 when it is on). Both US/EU DST divergence windows (US on / EU off in March, US
  on / EU off in late October-early November) are covered by construction — the London and New York rules
  are evaluated independently per date; no fixed UTC hour appears anywhere. Flat time = 16:00 Europe/London
  mapped the same way. Implementation note for the EA: a fixed-table `QM_SessionClock` helper with the IANA
  transition rules for both zones (the tester has no `zoneinfo`); unit-tested against the prescreen's
  `zoneinfo` mapping for 2018-2026.
- **Range:** the four M15 bars starting at anchor − 60, −45, −30, −15 min (all CLOSED at the anchor). Range
  high `RH` / low `RL` = max/min of their highs/lows; width `W = RH − RL`. At least three of the four bars
  must exist, otherwise no trade that day.
- **Thin-range floor / wide-range cap (named, frozen from the selection period):** trade only if
  `0.86 × ATR ≤ W ≤ 1.93 × ATR` on EURUSD and `0.88 × ATR ≤ W ≤ 2.06 × ATR` on GBPUSD, where ATR =
  Wilder ATR(14) on H1 bars closed at or before the anchor (p10 / p90 of the 2018-07..2022-12 W/ATR
  distribution; the same values are applied unchanged to 2023-25). Measured W: EURUSD p10/p50/p90 =
  7.9 / 14.5 / 27.6 pips (SEL), 8.1 / 13.7 / 25.7 (VAL); GBPUSD 13.2 / 22.1 / 40.8 (SEL), 11.0 / 18.6 / 34.9 (VAL).
- **Entry window:** the M15 bars starting in [anchor, anchor + 4 h). Signals are evaluated on CLOSED bars only
  (shift-1 contract: the decision for bar *i* is taken at the open of bar *i+1* using bars ≤ *i*).
- **Precedence (exact):** the FIRST M15 bar in the window whose high > RH or low < RL decides the day.
  (a) If that bar CLOSES beyond the range (close > RH or close < RL) → **breakout arm B** in the break
  direction. (b) If that bar closes back inside the range (wick-only excursion) → **failure arm F** against
  the wick side (short after an upper wick, long after a lower wick; if both sides wicked in the same bar the
  larger excursion decides). No other bar can trigger; B and F are mutually exclusive; one trade per symbol
  per day. The "closes beyond, next bar closes back inside" pattern is NOT a failure signal in this revision
  (it is a breakout trade that may be stopped).
- **Orders:** market entry at the open of the bar after the decision bar (no entry at or after the flat
  time); stop distance = `W` from the entry price; target arms **A15 = 1.5 × W** and **A20 = 2.0 × W** (two
  frozen arms, no choice left to the builder — each arm is its own card if ever built). Same-bar stop/target
  ambiguity resolves to the stop. Hard time-stop: flat at 16:00 Europe/London (0 % overnight by construction).
- **Risk:** RISK_FIXED 1000 in backtests, RISK_PERCENT live; framework news blackout applies (not modelled
  in the prescreen — it can only lower density); no martingale / grid / averaging; no ML.

## Density and cost (measured)

- Trading days 2018-07-02..2025-12-31: 1,929 (EURUSD) / 1,930 (GBPUSD). Day states EURUSD: 1,558 trades
  (818 B, 740 F), 178 floor-excluded, 185 cap-excluded, 3 no-signal, 5 no-range; GBPUSD: 1,524 trades
  (811 B, 713 F), 187 / 209 / 4 / 6.
- Density 0.75-0.80 trades/bd per symbol (1.5-1.6 combined) — the revision-1 prior (0.6-0.7) was slightly
  low; density was never the problem.
- Median hold 114 min (EURUSD) / 128 min (GBPUSD) for A15.
- Commission per trade at RISK_FIXED 1000 (registry model, worst-case DXZ/FTMO): EURUSD median 0.040R,
  p90 0.065R; GBPUSD median 0.031R, p90 0.050R. Spread: not in the `.DWX` data and not measured for FX
  majors on the FTMO venue — **evidence GAP, no figure invented**.

## Falsification criteria (as applied)

1. Density < 0.3 trades/bd/symbol → not met (0.75-0.80).
2. Net E[R] < +0.08R/trade after commission on the selection period → **met** (EURUSD −0.054, GBPUSD
   −0.068 for A15 B+F; every arm/variant/symbol is below +0.08 on SEL).
3. PF < 1.05 on the selection period → **met** (0.83-1.01).
4. Holdout: VAL ≥ 70 % of SEL R/bd → not evaluable (SEL negative); the sign flips between periods.
5. Joint tail EURUSD/GBPUSD (|r| > 0.30 or lower-decile co-occurrence > 2× baseline) → not evaluated
   (moot); the daily P/L series are in the prescreen output if ever needed.

Criteria 2 and 3 retire the hypothesis at the prescreen stage. Tail tests vs 10706 / 13213 / 10700 / H-V3
remain the requirement for any future re-authoring that passes the prescreen.

## Revision 2 (2026-09-21) — changes vs critique 1614737c

| critic point | resolution |
|---|---|
| target is an unresolved 1.5x-2.0x choice | two frozen arms A15 / A20, both measured, reported separately |
| thin-range floor unnamed | floor / cap named and frozen from the selection period: 0.86-1.93 × ATR(14,H1) EURUSD, 0.88-2.06 GBPUSD |
| no explicit new-bar / shift-1 contract | closed-bar contract stated: decision on closed bar *i*, entry at open of bar *i+1*, stop/target on subsequent bars, same-bar ambiguity → stop |
| exact false-break precedence missing | first-excursion-bar rule with (a) close-beyond → B, (b) wick-only → F, larger excursion on double wick, one trade/day |
| 0.6-0.7/bd and +0.10-0.15R were priors | replaced by measured 0.75-0.80/bd and −0.054 / −0.068R (SEL), +0.022 / +0.058R (VAL) |
| "pilot" was prior × 1175 arithmetic | measured fire counts: 1,558 / 1,524 trades over 1,958 business days |
| cost_R not computable (tester_defaults has no commission) | computed per trade from `live_commission.json` at the actual entry price and lots: median 0.040R / 0.031R; spread declared as GAP |
| measured fire-count prescreen per symbol/arm | `prescreen_extract.json` (sealed), script + reader in `tools/strategy_farm/session_tools/` |
| tail tests vs 10706 / 13213 / H-V3 | retained as a requirement; moot after falsification |
| provenance: manifest hashes ≠ files | resealed; `research_source.py verify` clean except `LEDGER_STATUS_BAD:draft` |

## Distinct from 13213 / 10706 / 10700 / 41475 / 41476 / 41477 / 41484

Unchanged from revision 1: same mechanism CLASS as 13213 but a different symbol and native session; the
corrective counterpart of the failed 41484 transplant; not competing with 10706's always-on swing logic
(46 % overnight) nor with 41477's continuous M15 EMA-reclaim trigger; different asset class from 10700 and
the 41475/41476 index trio.

## Source manifest

```qm-source-manifest
# Auto-generated by research_source.seal; do not hand-edit.
research.json:          e02878b27efbec83984a7df9e640778133e86cae9534120b36dd569dc11275a7
lineage.json:           c8bbea281ae43ff30ee0c5751bed8aab7c8b4b4ce44d92e2596ce4af3f56db9e
critic_receipt.json:    529e8710554d85fac62d435853a1c03f01bb3170f7efbc283a06b49d698cec14
baseline_extract.json:  5b291bdfab5f220ff53323b27c8a1295e9c9ef6b94d4ec7c0b87a577d5d4b15f
prescreen_extract.json: aba9c5b52ae361bc850beabbadbb85d5170098ea6e84de4480e159e19eb0a864
```
