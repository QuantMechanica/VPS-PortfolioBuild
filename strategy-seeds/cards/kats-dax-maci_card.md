---
card_schema_version: 2
strategy_id: KATSANOS-INTERMARKET-2008_S01
source_id: KATSANOS-INTERMARKET-2008
ea_id: TBD
slug: kats-dax-maci
type: strategy
status: DRAFT
g0_status: DRAFT
created: 2026-07-23
created_by: Research
last_updated: 2026-07-23
symbol: GDAXI.DWX
target_symbols: [GDAXI.DWX]
markets: [indices]
timeframes: [D1]
primary_target_symbols: [GDAXI.DWX]
timeframe: D1
variant_id: KATS_DAX_APPENDIX_A4
execution_contract_ref: TBD
execution_contract_status: BLOCKED
strategy_type_flags: [trend-filter-ma, time-stop, atr-hard-stop, friday-close-flatten, news-blackout, symmetric-long-short]
expected_trades_per_year_per_symbol: 13
expected_trade_frequency: "Source FDAX comparison: 51 trades in about 3.8 years, or 13.5/year; the GDAXI CFD port and framework exits are untested."
expected_pf: TBD
expected_dd_pct: TBD
risk_class: medium-high
ml_required: false
r1_track_record: PENDING_OWNER
r2_mechanical: PENDING_OWNER
r3_data_available: PENDING_OWNER
r4_ml_forbidden: PENDING_OWNER
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, enhancement_doctrine, news_pause_default, darwinex_native_data_only]
review_focus: "Daily DAX trend/congestion switching is a distinct source rule but adds another index swing sleeve; Q02 and later portfolio gates must prove value and orthogonality."
source_citations:
  - type: book
    citation: "Katsanos, Markos. Intermarket Trading Strategies. Wiley, 2008."
    location: "Chapter 13, book pp. 209-213 / PDFPAGE 227-231; Table 13.2, book p. 210 / PDFPAGE 228; Appendix A.4, book p. 329 / PDFPAGE 347."
    quality_tier: A
    role: primary
---

# Strategy Card — DAX CI-Regime MA/Stochastic

## Hypothesis

DAX daily behavior alternates between directional and congested regimes. The
source uses a Congestion Index to select either moving-average trend logic or
long-horizon stochastic reversal logic, with asymmetric long and short rules.
The proposed `GDAXI.DWX` port tests whether that regime switch survives the
change from continuous FDAX futures to a broker index CFD.

## 1. Source

The single canonical source is `KATSANOS-INTERMARKET-2008`, durably authorized
in `strategy-seeds/sources/KATSANOS-INTERMARKET-2008/source.md`.

Source locations:

- concept and rules: book pp. 209–213 / PDFPAGE 227–231;
- historical comparison: Table 13.2, book p. 210 / PDFPAGE 228;
- executable MetaStock formulas: Appendix A.4, book p. 329 /
  PDFPAGE 347;
- audited extraction:
  `docs/research/KATSANOS_CH13_CH17_EXTRACTION_2026-06.md`.

## 2. Concept

The strategy is long/short and evaluates completed D1 bars. A directional
Congestion Index state activates unequal fast/slow moving-average trend rules.
A low-absolute-CI state activates stochastic recovery or rollover rules. Signal
exits, a 60-bar time exit, and a proposed non-alpha catastrophe stop bound each
position.

## 3. Markets And Timeframes

- Source market: continuous FDAX futures, one contract.
- Research port and target symbol: `GDAXI.DWX`.
- Signal timeframe: D1.
- Entry timing: first executable tick of the next D1 bar after the source
  conditions are true on the completed bar.
- Registered local D1 history: 2018–2026.
- No additional symbol, macro series, calendar signal, or external runtime
  dataset is required.

## Rules

The exact Appendix A.4 Boolean expressions are the alpha baseline. Narrative
phrasing such as “crosses” does not replace an Appendix state comparison. The
only non-source mechanics are separately labelled in `QM interpretations`.

## Source-defined rules

For each completed D1 bar define:

```text
CI =
  ROC(Close,39,%)
  / (((HHV(High,40)-LLV(Low,40))/(LLV(Low,40)+0.01))+0.000001)

S5  = Stoch(5,3)
S40 = Stoch(40,3)
M   = MACD = EMA(Close,12)-EMA(Close,26)
```

`HHV` and `LLV` include the current completed signal bar. Comparisons are state
tests unless `Cross` is written explicitly.

## 4. Entry Rules

Enter at the next D1 open only while flat.

Long entry if either branch is true:

```text
TREND_LONG =
  CI > 30
  AND S5 > SMA(S5,3)
  AND SMA(Close,15) > SMA(Close,20)

CONGESTION_LONG =
  ABS(CI) < 25
  AND S5 > SMA(S5,3)
  AND LLV(S40,2) < 30
```

Short entry if either branch is true:

```text
TREND_SHORT =
  CI < -30
  AND ROC(CI,3,%) < 0
  AND S5 < SMA(S5,3)
  AND SMA(Close,10) < SMA(Close,20)
  AND SMA(Close,2) < SMA(Close,150)

CONGESTION_SHORT =
  ABS(CI) < 25
  AND ROC(CI,3,%) < 0
  AND S5 < SMA(S5,3)
  AND HHV(S40,2) > 70
```

Long and short branches are evaluated independently. If both directions were
ever true on one signal bar, remain flat and log an ambiguous-signal reject;
the source does not specify a same-bar tie-break.

## 5. Exit Rules

Exit a long at the next D1 open if either condition is true:

```text
HHV(CI,3)-CI > 40

OR

ABS(CI) < 20
AND S5 < SMA(S5,3)
AND HHV(S40,4) > 85
AND S40 < 75
```

Cover a short at the next D1 open if either condition is true:

```text
LLV(CI,3)-CI < -40

OR

CrossUp(MACD,EMA(MACD,7))
AND Close > EMA(Close,7)
```

Close either direction after 60 completed D1 bars in the position if no earlier
exit fires.

Protective stop in source: **none**. The source uses signal and time exits only.

## 6. Filters (No-Trade Module)

- Require at least 151 valid completed D1 bars plus indicator warm-up.
- Fail closed on missing/nonfinite OHLC, invalid indicator output, invalid
  account-governor state, unknown magic, or an existing position for this
  symbol/magic.
- Framework news blackout blocks entries only; it never blocks exits.
- Framework kill-switch and Friday-close behavior remain authoritative.
- No session filter, intermarket partner, spread-derived alpha filter, grid,
  martingale, averaging, pyramiding, or discretionary override.

## 7. Trade Management Rules

- One position per symbol and magic.
- No scale-in, partial close, break-even move, trailing alpha stop, or same-bar
  re-entry.
- A stop or forced framework exit leaves the strategy flat until a later
  completed D1 bar independently satisfies an entry branch.
- Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`; any live sizing remains
  outside this Draft Card and requires later authorization.

## QM interpretations

These items are QuantMechanica port or safety choices, not source claims:

1. Use `GDAXI.DWX` instead of continuous FDAX futures.
2. Treat Appendix A.4 as authoritative where its exact state tests are more
   specific than the Chapter 13 narrative.
3. Evaluate only completed D1 bars and enter/exit on the first eligible tick of
   the next broker D1 bar, matching the source's one-bar delay and next-open
   convention.
4. Proposed catastrophe stop: fixed `3.0 * ATR(20)` distance from entry, with
   ATR taken from the completed signal bar and never widened. This is a
   non-alpha FTMO risk overlay because the source supplies no protective stop.
5. Keep the V5 Friday-close default enabled. A Friday flatten is a framework
   exit; re-entry requires a fresh valid completed-bar state.
6. Do not reproduce the source's simplified futures commission, omitted
   slippage, continuous-contract rollover, or one-contract sizing assumptions
   as CFD evidence.

The execution contract remains `BLOCKED` until OWNER G0 accepts or changes the
catastrophe-stop and Friday-close interpretations.

## Framework execution overrides

- Kill switch: highest framework authority; exits are never entry-filter
  blocked.
- Friday close: proposed enabled at the V5 default Friday 21:00 broker time.
- News blackout: entry-only, fail closed on stale calendar state.
- Catastrophe stop: proposed fixed ATR(20) × 3.0 broker stop.
- Source signal and 60-bar time exits remain active.

## Exit precedence

Highest to lowest:

1. account kill switch or forced risk flatten;
2. broker catastrophe stop;
3. Friday-close framework flatten;
4. source signal exit on the completed D1 bar;
5. source 60-bar time exit.

If more than one reason is true, record the highest-precedence reason and do not
open a replacement position on the same tick.

## Runtime data dependencies

- Chart and signal data: `GDAXI.DWX`, D1 OHLC.
- Signal clock: native broker D1 boundary; no civil-time or DST conversion.
- Tester account currency: use the configured test account and framework
  contract-size/tick-value conversion, not the book's €25 FDAX point value.
- Finite dataset: registry currently records `GDAXI.DWX` D1 history for
  2018–2026.
- External dependencies: none.

## Parameters To Test

All alpha parameters are source locked for the first falsification build:

| Parameter | Baseline | Selection rule |
|---|---:|---|
| CI ROC/range | 39/40 | fixed |
| fast stochastic | 5,3 | fixed |
| congestion stochastic | 40,3 | fixed |
| long MAs | 15/20 | fixed |
| short MAs | 10/20 plus 2/150 | fixed |
| MACD | 12/26 with EMA7 comparison | fixed |
| time exit | 60 D1 bars | fixed |
| catastrophe stop | ATR20 × 3.0 | proposed fixed safety overlay |
| Friday close | enabled | proposed fixed framework default |

No alpha sweep or rescue threshold is authorized by this Draft. A change to a
source-locked value requires a new reviewed Card/version before testing.

## Author Claims

Table 13.2 reports 51 trades over the roughly 3.8-year 2004–2007 continuous
FDAX test, or approximately 13.5 trades/year, with a reported profit factor of
1.93. The Chapter states that the baseline did not beat buy-and-hold in that
strongly bullish final segment. These are historical source claims from book
p. 210 / PDFPAGE 228, not `GDAXI.DWX` evidence.

## Risk

- `expected_pf: TBD`; G0 may record a conservative ordering estimate, but only
  artifact-bound tests can establish performance.
- `expected_dd_pct: TBD`.
- Source cadence: 13.5/year on continuous FDAX; current planning integer is
  13/year on one symbol.
- Main risks: no source protective stop, index gaps, futures-to-CFD basis,
  short final source sample, parameter selection on older DAX data, Friday
  flatten changing holds, and overlap with existing index swing sleeves.
- Risk class: medium-high until the stop/fill/cost contract and Q02 behavior are
  observed.

## R1-R4 research precheck

- R1 proposed PASS: exactly one authorized source ID and precise pages.
- R2 proposed PASS: deterministic long/short entry, signal exits, and 60-bar
  time exit; source stop gap is explicit.
- R3 proposed PASS: `GDAXI.DWX` D1 is present, with a disclosed FDAX-to-CFD port.
- R4 proposed PASS: fixed arithmetic, no adaptive fit, ML, grid, martingale,
  pyramiding, or more than one position per magic.

These are Research findings only. OWNER has not recorded G0 approval.

## Non-Duplicate Decision

The closest existing families are:

- `QM5_10166_stochrsi-mr`: D1 StochRSI extreme reversion with an optional
  SMA200 filter, but no Katsanos CI or trend/congestion state switch;
- `QM5_10846_tv-growth-bo`: long-only EMA/StochRSI/volume breakout rather than
  symmetric CI-regime logic;
- `QM5_10231_tv-range-stoch`: H4 range-WMA/Stochastic logic, without the D1
  CI/MA state machine;
- `QM5_12966_gdaxi-weekly-oversold-swing`: SMA200 plus ten-day-low reversion,
  without this rule family.

No existing Card, EA, or registry row contains the ROC39/HHV40/LLV40
Congestion Index together with the source's fast/slow stochastic branches,
asymmetric moving averages, and 60-bar exit.

## Framework Alignment

- `no_trade`: data validity, one-position guard, news, Friday-close window, and
  kill switch.
- `trade_entry`: CI regime selection plus MA/stochastic branches.
- `trade_management`: 60-bar counter and fixed catastrophe stop state.
- `trade_close`: source signal exits, time exit, Friday close, and risk exits.

## Falsification and requalification

- Retire under the binding Q02 rule if realized density is below five completed
  trades/year/symbol; do not loosen thresholds to rescue cadence.
- Reject or recycle if the CFD port cannot produce deterministic signals, if
  costs erase the edge, or if the source-rule implementation cannot be
  reconciled to the Appendix block.
- A change to CI formula/thresholds, MA or stochastic periods, next-open timing,
  catastrophe stop, Friday handling, target symbol, or position lifecycle
  requires a new execution contract, binary, stream reconciliation, and full
  requalification.
- A zero-trade test triggers the zero-trades recovery process before any
  strategy verdict.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| draft-v1 | 2026-07-23 | source extraction and causal CFD port proposal | G0 pending | DRAFT |

No EA ID, magic row, code, build, test, deploy manifest, or live permission
exists for this Card.
