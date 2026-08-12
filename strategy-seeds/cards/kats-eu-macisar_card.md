---
card_schema_version: 2
strategy_id: KATSANOS-INTERMARKET-2008_S02
source_id: KATSANOS-INTERMARKET-2008
ea_id: QM5_20062
slug: kats-eu-macisar
type: strategy
status: APPROVED
g0_status: APPROVED
created: 2026-07-23
created_by: Research
last_updated: 2026-07-23
symbol: EURUSD.DWX
target_symbols: [EURUSD.DWX]
markets: [forex]
timeframes: [D1]
primary_target_symbols: [EURUSD.DWX]
timeframe: D1
variant_id: KATS_EUR_APPENDIX_A8_GT40
execution_contract_ref: TBD
execution_contract_status: DRAFT
strategy_type_flags: [trend-filter-ma, signal-reversal-exit, atr-hard-stop, friday-close-flatten, news-blackout, symmetric-long-short]
expected_trades_per_year_per_symbol: 12
expected_trade_frequency: "Source conventional EUR/USD comparison: 62 trades in five years, or 12.4/year; the causal next-open DWX port and framework exits are untested."
expected_pf: 1.2
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
r1_track_record: TIER_A
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
g0_approved_by: OWNER
g0_approval_date: 2026-07-23
g0_approval_reasoning: "R1 TIER_A licensed Wiley source; R2 deterministic Appendix A.8 ABS(CI)>40; R3 EURUSD.DWX D1 available without external series; R4 no ML. OWNER accepts next-open, ATR20x3, Friday21, and fail-closed tie-break."
r1_reasoning: "One OWNER-authorized licensed Wiley book with exact Chapter 17, Table 17.6, and Appendix A.8 page anchors; source tier A."
r2_reasoning: "Deterministic SMA-change-volatility, CI-turn, and Parabolic-SAR rules with the Appendix inequality frozen explicitly."
r3_reasoning: "EURUSD.DWX D1 is registered with 2017-2026 history and the approved conventional variant requires no CRB, TNX, or other external series."
r4_reasoning: "Fixed arithmetic only; no ML, adaptive fit, grid, martingale, pyramiding, or discretionary override."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, enhancement_doctrine, news_pause_default, darwinex_native_data_only]
review_focus: "A slow EUR/USD trend/regime sleeve may diversify index and commodity sleeves; the frozen Appendix inequality and overlap with existing PSAR/SMA families require strict Q02 and later portfolio evidence."
source_citations:
  - type: book
    citation: "Katsanos, Markos. Intermarket Trading Strategies. Wiley, 2008."
    location: "Chapter 17, book pp. 279-285 / PDFPAGE 297-303; equations 17.1-17.8 and Table 17.6; Appendix A.8, book p. 355 / PDFPAGE 373."
    quality_tier: A
    role: primary
---

# Strategy Card — EUR/USD Volatility-Filtered MA/CI/SAR

## Hypothesis

A ten-day moving average that moves farther than its own recent change
volatility may identify a new daily trend. Congestion Index direction and
Parabolic SAR state confirm that the move is directional rather than a
trendless fluctuation. The conventional source system uses no CRB, TNX, DXY, or
other external market series.

## 1. Source

The single canonical source is `KATSANOS-INTERMARKET-2008`, durably authorized
in `strategy-seeds/sources/KATSANOS-INTERMARKET-2008/source.md`.

Source locations:

- equations, explanation, and test design: book pp. 279–285 /
  PDFPAGE 297–303;
- conventional versus intermarket results: Table 17.6, book pp. 284–285 /
  PDFPAGE 302–303;
- executable enhanced-system formulas from which the conventional CRB/TNX-free
  comparator is derived: Appendix A.8, book p. 355 / PDFPAGE 373;
- audited extraction:
  `docs/research/KATSANOS_CH13_CH17_EXTRACTION_2026-06.md`.

## 2. Concept

This G0 Card extracts the conventional EUR/USD comparator reported separately in
Table 17.6. It is not the enhanced CRB/TNX system. The ten-day SMA must move by
more than a volatility-scaled threshold, price must be on the correct side of
Parabolic SAR, and the smoothed Congestion Index must turn in the trade
direction from a high-absolute-value state.

## 3. Markets And Timeframes

- Source market: EUR/USD spot, EUR 100,000 per trade.
- Research target symbol: `EURUSD.DWX`.
- Signal timeframe: D1.
- Causal port timing: calculate from the completed D1 bar and submit at the
  first eligible tick of the next broker D1 bar.
- Registered local D1 history: 2017–2026.
- No external macro or intermarket runtime dependency.

## Rules

This Card freezes the executable Appendix A.8 inequality
`ABS(CI) > 40` as variant `KATS_EUR_APPENDIX_A8_GT40`. The printed Chapter 17
equations use `ABS(CI) < 40`; that alternate publication form is retained as a
separate falsification diagnostic and is not eligible to replace this baseline
after seeing outcomes.

## Source-defined rules

For each completed D1 bar define:

```text
MA = SMA(Close,10)
PC = Ln(MA / MA[-1])
FILT = StdDev(PC,20)

CI_raw =
  ROC(Close,39,%)
  / (((HHV(High,40)-LLV(Low,40))/(LLV(Low,40)+0.01))+0.000001)

CI = EMA(CI_raw,7)
SAR = ParabolicSAR(step=0.04, maximum=0.10)
```

`HHV` and `LLV` include the current completed signal bar. The Appendix formula
adds `0.7 * FILT` directly to the moving-average value; this Card preserves
that literal expression and does not silently rescale it.

## 4. Entry Rules

Enter long while flat when all conditions are true on the completed D1 bar:

```text
MA > LLV(MA,3) + 0.7*FILT
AND Close > SAR
AND ABS(CI) > 40
AND CI > LLV(CI,3) + 3
```

Enter short while flat when all conditions are true:

```text
MA < HHV(MA,3) - 0.7*FILT
AND Close < SAR
AND ABS(CI) > 40
AND CI < HHV(CI,3) - 3
```

The operational port submits at the next D1 open. If both directions were ever
true on one signal bar, remain flat and log an ambiguous-signal reject.

## 5. Exit Rules

- Exit a long when the completed D1 close is below
  `ParabolicSAR(0.04,0.10)`.
- Cover a short when the completed D1 close is above
  `ParabolicSAR(0.04,0.10)`.
- Submit the source signal exit at the first eligible tick of the next D1 bar.

The source describes SAR as a trailing stop, but the printed formula is a daily
close condition. It does not define a resting intraday broker stop, a fixed
take-profit, or a time exit.

Protective broker stop in source: **none** beyond the daily SAR signal exit.

## 6. Filters (No-Trade Module)

- Require enough valid completed D1 history for the 40-bar CI, 20-bar
  volatility filter, and a deterministic Parabolic SAR warm-up.
- Fail closed on missing/nonfinite OHLC, invalid MA/FILT/CI/SAR output, invalid
  account-governor state, unknown magic, or an existing position for this
  symbol/magic.
- Framework news blackout blocks entries only; exits are never news blocked.
- Framework kill-switch and Friday-close behavior remain authoritative.
- No CRB, TNX, DXY, carry, session, grid, martingale, averaging, pyramiding, or
  discretionary filter.

## 7. Trade Management Rules

- One position per symbol and magic.
- No scale-in, partial close, break-even move, alpha trailing stop, take-profit,
  or same-bar re-entry.
- A broker-stop or forced framework exit leaves the strategy flat until a later
  completed D1 bar independently satisfies the full entry rule.
- Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`; live sizing is outside
  this G0 Card and requires later authorization.

## QM interpretations

These items are QuantMechanica execution or safety choices:

1. Use the Appendix `ABS(CI) > 40` branch as the frozen baseline because it is
   the only executable publication form and matches the prose's intent to
   filter trendless periods. The Chapter's `<40` equations remain disclosed.
2. Convert the source's idealized same-day-close fill into a causal
   completed-D1-signal/next-bar-open fill. This port does not claim to reproduce
   Table 17.6.
3. If an implementation ever observes simultaneous long and short entry
   states, remain flat and log the reject. The source defines no same-bar
   direction priority.
4. Use `EURUSD.DWX` broker D1 bars and current contract/tick-value metadata
   instead of the source vendor's EUR 100,000 lot and one-pip commission model.
5. Proposed catastrophe stop: fixed `3.0 * ATR(20)` distance from entry, using
   ATR from the completed signal bar and never widening it. It is a non-alpha
   risk overlay.
6. Keep the V5 Friday-close default enabled. Re-entry requires a fresh complete
   source signal after the forced flatten.

OWNER G0 accepted the Appendix-inequality variant, causal fill, tie-break,
catastrophe stop, and Friday handling on 2026-07-23. The execution-contract
state is now `DRAFT`: this Card authorizes build and non-live falsification,
but it is not a separately approved T6/live execution contract.

## Framework execution overrides

- Kill switch: highest authority.
- Catastrophe stop: proposed fixed ATR(20) × 3.0 broker stop.
- Friday close: proposed enabled at Friday 21:00 broker time.
- News blackout: entry-only and fail closed on stale calendar state.
- Source SAR close signal remains active and is never entry-filter blocked.

## Exit precedence

Highest to lowest:

1. account kill switch or forced risk flatten;
2. broker catastrophe stop;
3. Friday-close framework flatten;
4. source Parabolic SAR close signal.

Do not open a replacement position on the same tick as a forced or source exit.

## Runtime data dependencies

- Chart and signal data: `EURUSD.DWX`, D1 OHLC.
- Signal clock: native broker D1 boundary; no civil-time or DST conversion.
- Parabolic SAR: deterministic local calculation using step 0.04 and maximum
  0.10; seed and warm-up method must be fixed in the execution contract.
- Finite dataset: registry currently records `EURUSD.DWX` D1 history for
  2017–2026.
- External dependencies: none.

## Parameters To Test

The first falsification build has no selectable alpha sweep:

| Parameter | Baseline | Selection rule |
|---|---:|---|
| SMA period | 10 | fixed |
| MA-change volatility | log change, StdDev20 | fixed |
| threshold multiplier | 0.7 | fixed |
| CI ROC/range/smoothing | 39/40/EMA7 | fixed |
| CI absolute gate | `>40` | fixed Appendix variant |
| CI turn threshold | 3 | fixed |
| Parabolic SAR | step 0.04, max 0.10 | fixed |
| catastrophe stop | ATR20 × 3.0 | proposed fixed safety overlay |
| Friday close | enabled | proposed fixed framework default |

The equation-form `<40` interpretation may be reported only as a
pre-registered, non-selecting diagnostic. It cannot replace a failed `>40`
baseline without a new Card/version and OWNER review.

## Author Claims

Table 17.6 reports 62 trades over the five-year conventional-system test,
approximately 12.4 trades/year, and a reported profit factor of 1.70. The
source labels 2003-01-22 through 2008-01-21 as the reserved test segment. Those
figures are historical source claims, not `EURUSD.DWX` results, and the
published CI inequality conflict prevents an unqualified reproduction claim.

## Risk

- `expected_pf: 1.20`; conservative G0 ordering prior only.
- `expected_dd_pct: 20.0`; conservative G0 ordering prior only.
- Source cadence: 12.4/year; current planning integer is 12/year.
- Main risks: the CI publication conflict, causal close-to-next-open deviation,
  no source broker stop, SAR seeding differences, long D1 holds, weekend/news
  gaps, source-vendor versus broker bars, and overlap with existing PSAR/SMA
  families.
- Risk class: medium-high until the execution contract and Q02 behavior are
  observed.

## R1-R4 G0 record

- R1 `TIER_A`: exactly one authorized licensed source ID with exact page anchors.
- R2 `PASS` for the frozen Appendix variant: deterministic entries and
  SAR exits; missing source broker stop is explicit.
- R3 `PASS`: `EURUSD.DWX` D1 is registered and no external partner is
  required.
- R4 `PASS`: fixed arithmetic, no adaptive fit, ML, grid, martingale,
  pyramiding, or multiple positions per magic.

OWNER recorded G0 approval on 2026-07-23. These findings authorize
implementation and non-live falsification only; they are not test evidence or
live permission.

## Non-Duplicate Decision

The closest existing families are:

- `QM5_10125_psar-sma-stop`: PSAR plus SMA50/200 and a percentage trail, without
  this MA-change volatility trigger or Congestion Index;
- `QM5_11411_wilder-parabolic-sar-reversal-d1`: always-in-market PSAR reversal
  without MA/CI entry logic;
- `QM5_10205_tv-chop-dmi-psar`: H1 Choppiness/DMI/PSAR, where Choppiness Index
  is not Katsanos' Congestion Index;
- `QM5_12742_nnfx-configurable-engine`: generic configurable D1 engine that
  cannot express the exact CI and MA-turn rule.

No existing Card, EA, or registry row implements the source's combined
SMA-change-volatility, CI-turn, and SAR rule.

## Framework Alignment

- `no_trade`: data validity, one-position guard, news, Friday-close window, and
  kill switch.
- `trade_entry`: volatility-filtered SMA turn plus Appendix CI and SAR gates.
- `trade_management`: fixed catastrophe stop state.
- `trade_close`: source SAR close, Friday close, and risk exits.

## Falsification and requalification

- Retire under the binding Q02 rule if realized density is below five completed
  trades/year/symbol; do not change the CI inequality or thresholds to rescue
  cadence.
- Reject or recycle if the causal port cannot reconcile its signals to the
  Appendix variant, if costs erase the edge, or if SAR seeding is not
  deterministic.
- Any change to the CI inequality/formula, MA/FILT expression, SAR parameters,
  next-open timing, catastrophe stop, Friday handling, target symbol, or
  lifecycle requires a new execution contract, binary, stream reconciliation,
  and full requalification.
- A zero-trade test triggers the zero-trades recovery process before any
  strategy verdict.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| draft-v1 | 2026-07-23 | source extraction and causal EURUSD port proposal | G0 review | DRAFT |
| g0-v1 | 2026-07-23 | OWNER accepted Appendix A.8 `ABS(CI)>40` and all stated QM execution interpretations | G0 | APPROVED |

EA ID `QM5_20062` is allocated. No magic row, code, build, test, deploy
manifest, separately approved execution contract, or live permission exists
for this Card.
