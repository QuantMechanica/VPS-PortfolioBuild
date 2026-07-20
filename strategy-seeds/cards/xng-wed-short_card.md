---
ea_id: QM5_20018
slug: xng-wed-short
type: strategy
strategy_id: BOROWSKI-COMM-DOW-2016_S01
source_id: BOROWSKI-COMM-DOW-2016
status: APPROVED
created: 2026-07-20
created_by: Research
last_updated: 2026-07-20
g0_status: APPROVED
g0_approval_reasoning: "OWNER commodity-sleeve mission: R1 tier-B complete peer-reviewed source; R2 exact XNG Wednesday short/next-D1 flat rule with fixed V5 risk; R3 registered XNG D1 route; R4 calendar/ATR only, no ML or banned indicator; deterministic tool and content-level Wednesday mechanic audit CLEAN."
source_citation: "Borowski, K. (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts with the Following Underlying Instruments: Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs and Lumber. Journal of Management and Financial Sciences, issue 26, 27-44."
source_citations:
  - type: academic_paper
    citation: "Borowski, Krzysztof (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts with the Following Underlying Instruments: Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs and Lumber. Journal of Management and Financial Sciences, issue 26, 27-44."
    location: "Section 3 day-of-week method; Section 4.1 natural-gas weekday result; official archive https://econjournals.sgh.waw.pl/JMFS/Archives_2015_2016; complete author-uploaded text https://www.researchgate.net/publication/303285422_ANALYSIS_OF_SELECTED_SEASONALITY_EF-_FECTS_IN_MARKETS_OF_FUTURE_CONTRACTS_WITH_THE_FOLLOWING_UNDERLYING_INSTRUMENTS_CRUDE_OIL_BRENT_OIL_HEATING_OIL_GAS_OIL_NATURAL_GAS_FEEDER_CATTLE_LIVE_CATTLE_LEAN_HOGS_AND_LUMBER"
    quality_tier: B
    role: primary
sources:
  - "[[sources/BOROWSKI-COMM-DOW-2016]]"
concepts:
  - "[[concepts/natural-gas-calendar-seasonality]]"
  - "[[concepts/wednesday-calendar-fade]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, day-of-week, short-only, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
period: D1
primary_target_symbols: [XNGUSD.DWX]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
expected_trade_frequency: "About 45-52 XNG one-session packages/year because only broker Wednesday D1 bars qualify; Q02 must verify at least five completed packages/year."
expected_trades_per_year_per_symbol: 48
expected_pf: 1.02
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: TIER_B
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: READY
q02_status: NOT_STARTED
review_focus: "Strictly falsify the XNG Wednesday one-session short after costs and futures/CFD calendar basis; test realized portfolio correlation only at its governed downstream gate."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, low_frequency, cfd_source_basis, multiple_comparisons, portfolio_correlation]
---

# XNG Wednesday One-Session Short

## Hypothesis

Borowski reports that Wednesday had a `-0.2664%` mean daily return for NYMEX
natural-gas futures in a 1990-2016 sample, with equality against other
weekdays rejected at reported `p=0.0136`. A sparse short-only carrier can test
whether that exact weekday return survives on the Darwinex continuous CFD
after explicit costs and fixed-risk controls.

This is a diversification candidate, not certification or a decorrelation
claim. It is structurally distinct from the book's XNG cumulative-RSI2
pullback because its decision uses only a broker weekday and holds one session.
Q02 and later portfolio analysis must establish whether its realized returns
add anything to XAU, SP500, NDX, XNG and the rest of the book. Nothing in this
card changes the portfolio gate.

## Source and interpretation boundary

The sole evidence lineage is the complete Borowski article cited above. It
studies NYMEX natural-gas futures from 1990-04-03 through 2016-03-31 and
compares each weekday's daily-return population with all other weekdays. Its
natural-gas table shows a negative Wednesday mean and reports the mean-
equality rejection above.

The study searches many commodities and calendar partitions without a
reported multiple-comparison correction. Its mean tests assume normal return
populations, the evidence ends before the current regime, and it does not
establish transfer from futures settlements to `XNGUSD.DWX` broker D1 bars.
The reported mean and p-value are source facts rather than a QM performance
forecast. This card therefore locks one baseline and permits no weekday,
direction, hold or stop sweep.

## Author claims

The author identifies a natural-gas Wednesday day-of-week anomaly and reports
the Wednesday mean and mean-equality test stated above. The card does not add
a causal storage, weather or inventory explanation that the source did not
test. ATR, spread, news, restart and risk controls are explicitly QM plumbing.

## Concept and non-duplicate decision

On a new `XNGUSD.DWX` D1 bar:

- enter one SELL only if the bar timestamp is broker-calendar Wednesday;
- flatten at the first subsequent D1 bar before any new-entry gate; and
- after an entry attempt, fill, stop, rejected order or restart, never retry
  on the same broker-calendar Wednesday.

The deterministic dedup tool returned CLEAN for `xng-wed-short`, strategy
`BOROWSKI-COMM-DOW-2016_S01`, the named author and the exact mechanic. Manual
repository inspection found no unconditional Wednesday-entry XNG carrier.

- `QM5_12567_cum-rsi2-commodity` uses SMA200 and cumulative RSI2 pullback
  state, not calendar timing.
- `QM5_12818_xng-tue-prem` buys Tuesday; `QM5_12819_xng-thu-fade` sells
  Thursday; `QM5_12806_xng-rev-weekend` trades Monday and Friday.
- `QM5_20011_xng-thu-tue` exits at Wednesday open, so it does not hold the
  Wednesday return.
- XNG storage EAs require event timing and price state even when Wednesday is
  in an allowed release window.
- `QM5_20017_xng-dom15-long` is a separate long monthly numbered-date result
  from the same paper, not a weekday trade.

The exact author-plus-mechanic-plus-parameter family is new. Different logic
does not guarantee low correlation, so portfolio admission remains downstream.

## rules

- Sell only the first executable tick of a genuine broker Wednesday D1 bar.
- Flatten at the first executable tick of the following D1 bar, with a
  one-calendar-day stale retry guard and the frozen broker hard stop.
- Consume the exact Wednesday attempt before all fallible entry gates; never
  shift or retry it later in the session.
- Keep one position per registered magic/symbol and use no adaptive logic.

## Markets, timeframe and cadence

- Target: `XNGUSD.DWX`, magic slot 0 only.
- Host and signal timeframe: D1.
- Decision cadence: one check on each new broker D1 bar.
- Expected frequency: about 45-52 completed packages per full year.
- Expected hold: one D1 session.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Runtime data: MT5 broker calendar, D1 ATR, spread, deal history and position
  state only.

## 4. Entry Rules

- Consume only a genuine new `XNGUSD.DWX` D1 bar.
- Require MQL broker `day_of_week == 3` for Wednesday, where Sunday is zero.
- Require no same-magic open position, same-day entry deal, or persisted
  same-day attempt marker.
- Mark the Wednesday attempted before news, spread, ATR, price or order checks
  so a blocked or rejected event cannot create a later intraday retry. Ignore
  future persisted state on historical reruns to preserve deterministic tests.
- Require the locked baseline and a nonnegative spread no greater than 2500
  points.
- Read completed-bar D1 `ATR(20)` and SELL with a frozen
  `2.75 * ATR(20)` broker hard stop; no take-profit.
- Framework news and kill-switch gates remain authoritative. If they block
  the exact bar, do not shift the signal to Thursday.

## 5. Exit Rules

- At the first D1 bar after the entry bar, close the package before applying
  any entry-news gate.
- Also close once one calendar day has elapsed as a stale-position guard.
- Keep framework Friday close enabled at broker hour 21, although a normal
  Wednesday package exits before Friday.
- The frozen broker hard stop remains active throughout the session.
- No trailing stop, break-even, partial close, scale-in, pyramiding, grid,
  martingale, long leg or discretionary exit.

## 6. Filters (No-Trade Module)

- Exact host/timeframe/slot: `XNGUSD.DWX`, D1, slot 0.
- Strategy constants are locked to Wednesday, ATR 20, multiplier 2.75,
  one-calendar-day stale guard and 2500-point spread cap.
- One position and at most one attempt per broker Wednesday, including restart.
- Zero modeled `.DWX` spread is valid; invalid/negative spread, price, ATR or
  stop arithmetic fails closed.
- No external data, price-direction filter, banned indicator, ML, adaptive
  parameter or PnL fit.

## 7. Trade Management Rules

- Evaluate deterministic exits before the new-entry news gate on every tick,
  retaining next-D1 close retries if the boundary request is rejected.
- Manage only the registered symbol and magic; never touch another EA's
  position.
- Do not modify the frozen stop after entry and do not open a replacement
  package on the same broker Wednesday.

## Parameters to test

| parameter | default | authorized baseline | role |
|---|---:|---:|---|
| `strategy_entry_dow` | 3 | 3 | broker Wednesday, Sunday=0 |
| `strategy_atr_period` | 20 | 20 | completed D1 ATR hard-stop estimate |
| `strategy_atr_sl_mult` | 2.75 | 2.75 | frozen stop distance |
| `strategy_max_hold_days` | 1 | 1 | stale guard; next-D1 exit is primary |
| `strategy_max_spread_points` | 2500 | 2500 | XNG entry spread cap |

All values and the short-only direction are locked. A different weekday,
direction, hold duration, stop or price filter requires a new approved card.

## Initial risk profile and kill criteria

- `expected_pf: 1.02` is a conservative queue-order prior, not evidence.
- `expected_dd_pct: 35.0` reflects natural-gas gaps and one-session tail risk,
  not a forecast.
- Retire at Q02 for fewer than five completed packages/year/symbol, zero
  trades, non-Wednesday entries, duplicate same-day attempts, invalid risk
  mode, nondeterminism, or failure of governed net PF/DD thresholds.
- Treat multiple comparisons, post-2016 decay, broker-session mapping and
  futures/CFD basis as explicit falsification risks.
- Later gates must kill the sleeve if realized correlation does not add the
  requested commodity diversification. Correlation is never a G0 waiver.

## risk

Q02 uses only `RISK_FIXED=1000`, `RISK_PERCENT=0` and
`PORTFOLIO_WEIGHT=1`. Each entry carries a frozen completed-bar ATR stop. No
live allocation is defined, and the source mean is not used as a sizing input.

## Strategy allowability check

- [x] R1 tier B: one peer-reviewed named-author article, official issue
  archive and complete public author copy; statistics and weaknesses disclosed.
- [x] R2 mechanical: exact Wednesday, short-only, next-D1/stale exit, ATR
  stop, spread cap and restart-safe no-retry state.
- [x] R3 testable: registered `XNGUSD.DWX` D1 route; no external runtime feed.
- [x] R4 compliant: deterministic calendar/ATR only; no ML, banned indicator,
  adaptive fit, grid, martingale, pyramiding or multi-position magic.
- [x] Exact unconditional XNG Wednesday mechanic dedup search is clean; all
  fuzzy weekday/event neighbors are disclosed above.

## Framework alignment

- no_trade: exact symbol/D1/slot and locked baseline parameters.
- trade_entry: exact broker Wednesday, daily attempt/history guard, short
  market order and frozen ATR stop.
- trade_management: next-D1 and one-day stale closure before entry-news gating.
- trade_close: `QM_TM_ClosePosition(..., QM_EXIT_STRATEGY)`, framework Friday
  close and broker hard stop.

`hard_rules_at_risk`:

- `friday_close`: enabled at broker hour 21; no card override.
- `risk_mode_dual`: this build creates only a `RISK_FIXED` backtest setfile.
- `low_frequency`: 45-52 packages/year is a prior; Q02 must prove at least five.
- `cfd_source_basis`: NYMEX futures are not assumed equal to the Darwinex CFD.
- `multiple_comparisons`: the source p-value is unadjusted across a broad
  calendar search.
- `portfolio_correlation`: diversification is a mission target, not an
  untested card claim.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-20 | initial structural XNG Wednesday card | G0 | APPROVED |

## Safety boundary

This card authorizes one research/backtest build and Q02 enqueue. It does not
authorize a live setfile, AutoTrading, T_Live, deploy/T_Live manifests,
portfolio admission, or any portfolio-gate change.
