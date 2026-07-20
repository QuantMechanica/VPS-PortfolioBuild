---
ea_id: QM5_20017
slug: xng-dom15-long
type: strategy
strategy_id: BOROWSKI-XNG-DOM15-2016_S01
source_id: BOROWSKI-XNG-DOM15-2016
status: APPROVED
created: 2026-07-20
created_by: Research
last_updated: 2026-07-20
g0_status: APPROVED
g0_approval_reasoning: "OWNER commodity-sleeve mission: R1 tier-B complete peer-reviewed source; R2 exact XNG day-15 long/next-D1 flat rule with no date shift and fixed V5 risk; R3 registered XNG D1 route; R4 calendar/ATR only, no ML or banned indicator; exact recurring DOM15 XNG mechanic audit CLEAN."
source_citation: "Borowski, K. (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts with the Following Underlying Instruments: Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs and Lumber. Journal of Management and Financial Sciences, issue 26, 27-44."
source_citations:
  - type: academic_paper
    citation: "Borowski, Krzysztof (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts with the Following Underlying Instruments: Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs and Lumber. Journal of Management and Financial Sciences, issue 26, 27-44."
    location: "Section 3 day-of-month method; Section 4.3 natural-gas result; official archive https://econjournals.sgh.waw.pl/JMFS/Archives_2015_2016; complete author-uploaded text https://www.researchgate.net/publication/303285422_ANALYSIS_OF_SELECTED_SEASONALITY_EF-_FECTS_IN_MARKETS_OF_FUTURE_CONTRACTS_WITH_THE_FOLLOWING_UNDERLYING_INSTRUMENTS_CRUDE_OIL_BRENT_OIL_HEATING_OIL_GAS_OIL_NATURAL_GAS_FEEDER_CATTLE_LIVE_CATTLE_LEAN_HOGS_AND_LUMBER"
    quality_tier: B
    role: primary
sources:
  - "[[sources/BOROWSKI-XNG-DOM15-2016]]"
concepts:
  - "[[concepts/natural-gas-calendar-seasonality]]"
  - "[[concepts/day-of-month-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, day-of-month, long-only, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
period: D1
primary_target_symbols: [XNGUSD.DWX]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
expected_trade_frequency: "About 8-10 XNG one-session packages/year because only broker D1 bars dated exactly the 15th qualify; Q02 must verify at least five completed packages/year."
expected_trades_per_year_per_symbol: 9
expected_pf: 1.02
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: TIER_B
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: PENDING
review_focus: "Strictly falsify the recurring XNG day-15 one-session premium after costs and futures/CFD basis; test realized portfolio correlation only at its governed downstream gate."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, low_frequency, cfd_source_basis, multiple_comparisons, portfolio_correlation]
---

# XNG Calendar-Day-15 One-Session Premium

## Hypothesis

Borowski reports that the NYMEX natural-gas session associated with calendar
day 15 had the largest mean among numbered days in a 1990-2016 sample:
`+0.9881%`, with equality against other days rejected at reported `p=0.0008`.
A sparse long-only carrier can test whether that exact recurring calendar
session survives on the Darwinex continuous CFD after explicit costs and
fixed-risk controls.

This is a diversification candidate, not a certification or decorrelation
claim. It is structurally distinct from the book's XNG RSI pullback, but Q02
and later portfolio analysis must establish whether its realized returns add
anything to XAU, SP500, NDX, XNG and the rest of the book. Nothing in this card
changes the portfolio gate.

## Source and interpretation boundary

The sole evidence lineage is the complete Borowski article cited above. It
studies NYMEX natural-gas futures from 1990-04-03 through 2016-03-31, compares
each numbered calendar day's daily-return population with all other days, and
identifies day 15 as natural gas's maximum mean and only statistically
significant day-of-month result.

The study searches many commodities and calendar partitions, including 31
numbered days, without a reported multiple-comparison correction. It assumes
normal return populations for the mean tests, ends before the current market
regime, and does not establish transfer from futures to `XNGUSD.DWX`. The
reported mean and p-value are source facts, not a QM performance forecast.
This card therefore locks one baseline and permits no neighboring-day or
parameter sweep.

## Concept and non-duplicate decision

On a new `XNGUSD.DWX` D1 bar:

- enter one BUY only if the broker-calendar date is exactly day 15;
- skip the month if no D1 bar is dated the 15th--never shift to a nearby bar;
- flatten at the first subsequent D1 bar before any new-entry gate; and
- after an entry attempt, fill, stop, rejected order or restart, never retry
  inside the same broker month.

Repository-wide searches found no recurring one-session XNG DOM15 carrier.

- `QM5_12567_cum-rsi2-commodity` uses SMA200 plus cumulative RSI2 pullback
  logic, not calendar timing.
- `QM5_12818`, `QM5_12819` and `QM5_20011` are weekday sleeves.
- `QM5_13009_xng-tom-mom` is turn-of-month momentum.
- `QM5_20013` and `QM5_20014` use two-month return and monthly channel states.
- `QM5_12813_eia-energy-switch` holds a paired broad seasonal regime from
  May 15 to August 31; it does not isolate every available XNG day-15 session.
- `QM5_12725_eia-xng-prestor` is an event-conditioned storage setup; incidental
  date overlap is not the same trigger, direction or hold.

The exact author-plus-mechanic-plus-parameter family is new. Different logic
does not guarantee low correlation, so portfolio admission remains downstream.

## Markets, timeframe and cadence

- Target: `XNGUSD.DWX`, magic slot 0 only.
- Host and signal timeframe: D1.
- Decision cadence: one check on each new broker D1 bar.
- Expected frequency: about 8-10 completed packages per full year.
- Expected hold: one D1 session; Friday close handles Friday-the-15th.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Runtime data: MT5 broker calendar, D1 ATR, spread, deal history and position
  state only.

## 4. Entry Rules

- Consume only a new `XNGUSD.DWX` D1 bar.
- Require `day == 15` in that bar's broker-calendar timestamp.
- Require no same-magic open position, same-month entry deal, or persisted
  same-month attempt marker.
- Mark the month attempted before sending the order so a rejection cannot
  create an intramonth retry. Ignore future persisted state on historical
  reruns to preserve deterministic tests.
- Require the locked baseline and a nonnegative spread no greater than 2500
  points.
- Read completed-bar D1 `ATR(20)` and BUY with a frozen
  `2.75 * ATR(20)` broker hard stop; no take-profit.
- Framework news and kill-switch gates remain authoritative. If they block
  the exact bar, do not shift the signal to a later date.

## 5. Exit Rules

- At the first D1 bar after the entry bar, close the package before applying
  any entry-news gate.
- Also close once one calendar day has elapsed as a stale-position guard.
- Keep Friday close enabled at broker hour 21 so a Friday-the-15th entry does
  not become a weekend exposure.
- The frozen broker hard stop remains active throughout the session.
- No trailing stop, break-even, partial close, scale-in, pyramiding, grid,
  martingale, short leg or discretionary exit.

## 6. Filters (No-Trade Module)

- Exact host/timeframe/slot: `XNGUSD.DWX`, D1, slot 0.
- Strategy constants are locked to day 15, ATR 20, multiplier 2.75,
  one-calendar-day stale guard and 2500-point spread cap.
- One position and at most one attempt per broker month, including restart.
- Zero modeled `.DWX` spread is valid; invalid/negative spread, price, ATR or
  stop arithmetic fails closed.
- No external data, price-direction filter, banned indicator, ML, adaptive
  parameter or PnL fit.

## 7. Trade Management Rules

- Evaluate deterministic exits before the new-entry news gate on every new D1
  bar, so an expired package cannot be retained by a blocked entry.
- Manage only the registered symbol and magic; never touch another EA's
  position.
- Do not modify the frozen stop after entry and do not open a replacement
  package during the same broker month.

## Parameters to test

| parameter | default | authorized baseline | role |
|---|---:|---:|---|
| `strategy_entry_day` | 15 | 15 | exact broker calendar date; no shift |
| `strategy_atr_period` | 20 | 20 | completed D1 ATR hard-stop estimate |
| `strategy_atr_sl_mult` | 2.75 | 2.75 | frozen stop distance |
| `strategy_max_hold_days` | 1 | 1 | stale guard; next-D1 exit is primary |
| `strategy_max_spread_points` | 2500 | 2500 | XNG entry spread cap |

All values and the long-only direction are locked. A different date, date
window, short direction, hold duration or price filter requires a new card.

## Initial risk profile and kill criteria

- `expected_pf: 1.02` is a conservative queue-order prior, not evidence.
- `expected_dd_pct: 35.0` reflects natural-gas gaps and single-session tail
  risk, not a forecast.
- Retire at Q02 for fewer than five completed packages/year/symbol, zero
  trades, shifted-date behavior, duplicate intramonth attempts, invalid risk
  mode, nondeterminism, or failure of the governed net PF/DD thresholds.
- Treat the paper's multiple comparisons, post-2016 decay and futures/CFD
  basis as explicit falsification risks.
- Later gates must kill the sleeve if realized correlation does not add the
  requested commodity diversification. Correlation is never a G0 waiver.

## Strategy allowability check

- [x] R1 tier B: one peer-reviewed named-author article, official issue
  archive and complete public author copy; statistics and weaknesses disclosed.
- [x] R2 mechanical: exact day 15, long-only, no shift, next-D1/stale exit,
  ATR stop, spread cap and restart-safe no-retry state.
- [x] R3 testable: registered `XNGUSD.DWX` D1 route; no external runtime feed.
- [x] R4 compliant: deterministic calendar/ATR only; no ML, banned indicator,
  adaptive fit, grid, martingale, pyramiding or multi-position magic.
- [x] Exact recurring DOM15 XNG mechanic dedup search is clean; all fuzzy
  calendar neighbors are disclosed above.

## Framework alignment

- no_trade: exact symbol/D1/slot and locked baseline parameters.
- trade_entry: exact broker day 15, monthly attempt/history guard, long market
  order and frozen ATR stop.
- trade_management: next-D1 and one-day stale closure before entry-news gating.
- trade_close: `QM_TM_ClosePosition(..., QM_EXIT_STRATEGY)`, framework Friday
  close and broker hard stop.

`hard_rules_at_risk`:

- `friday_close`: enabled; needed to preserve a one-session Friday entry.
- `risk_mode_dual`: this build creates only a `RISK_FIXED` backtest setfile.
- `low_frequency`: 8-10 packages/year is a prior; Q02 must prove at least five.
- `cfd_source_basis`: NYMEX futures are not assumed equal to the Darwinex CFD.
- `multiple_comparisons`: the source p-value is unadjusted across a broad
  calendar search.
- `portfolio_correlation`: diversification is a mission target, not an
  untested card claim.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-20 | initial structural XNG DOM15 card | G0 | APPROVED |

## Safety boundary

This card authorizes one research/backtest build and Q02 enqueue. It does not
authorize a live setfile, AutoTrading, T_Live, deploy/T_Live manifests,
portfolio admission, or any portfolio-gate change.
