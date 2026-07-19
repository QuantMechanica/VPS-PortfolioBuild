---
strategy_id: MEEK-HOELSCHER-XNG-DOW-2023_S03
source_id: MEEK-HOELSCHER-XNG-DOW-2023
ea_id: QM5_20011
slug: xng-thu-tue
status: APPROVED
created: 2026-07-19
created_by: Research
last_updated: 2026-07-19
g0_status: APPROVED
source_citation: "Meek, Andrew C. and Hoelscher, Seth A. (2023). Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics & Finance 11(1), 2213876. DOI 10.1080/23322039.2023.2213876."
source_citations:
  - type: paper
    citation: "Meek, Andrew C. and Hoelscher, Seth A. (2023). Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics & Finance 11(1), 2213876."
    location: "Section 4 and Table 6, printed pages 15-16; DOI https://doi.org/10.1080/23322039.2023.2213876; full open text https://www.econstor.eu/bitstream/10419/304091/1/10.1080_23322039.2023.2213876.pdf"
    quality_tier: A
    role: primary
sources:
  - "[[sources/MEEK-HOELSCHER-XNG-DOW-2023]]"
concepts:
  - "[[concepts/natural-gas-day-of-week-seasonality]]"
  - "[[concepts/thursday-tuesday-calendar-carry]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [session-close-seasonality, atr-hard-stop, time-stop, long-only, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
primary_target_symbols: [XNGUSD.DWX]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "One Thursday-close to Tuesday-close Natural Gas package per broker week; approximately 45-52 completed packages/year after holidays and framework entry filters."
expected_trades_per_year_per_symbol: 48
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
review_focus: "Falsify the source-explicit weekly Natural Gas calendar carry on the Darwinex CFD proxy; futures/CFD session mapping, weekend gaps, costs, expectancy, and realized correlation are unproven."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, darwinex_native_data_only]
g0_approval_reasoning: "R1 PASS peer-reviewed open source with exact Section 4 rule; R2 PASS fixed weekly Thursday-close to Tuesday-close lifecycle and ATR hard stop; R3 PASS XNGUSD.DWX D1 registered; R4 PASS deterministic native-data logic with no ML, banned indicators, grid or martingale; sibling return-window overlap disclosed."
---

# XNG Thursday-Close to Tuesday-Close Calendar Carry

## Hypothesis

Natural Gas futures returns are distributed unevenly through the week. Meek
and Hoelscher report positive Monday and Tuesday effects and a negative
Thursday effect across asymmetric volatility specifications, then state a
single weekly implementation: enter long at Thursday's close and leave at
Tuesday's close. Holding only that interval may isolate a structural calendar
premium while avoiding the source's negative Thursday return window.

## Source And Evidence Boundary

The approved source is the complete peer-reviewed open-access article by Meek
and Hoelscher (2023), *Cogent Economics & Finance* 11(1), article 2213876,
DOI `10.1080/23322039.2023.2213876`. It studies synchronized front-/second-month
energy futures from 2002-2021 and reports Natural Gas weekday coefficients
using GARCH, EGARCH, PGARCH, QGARCH and TGARCH specifications.

This card does not implement any GARCH model. The model family establishes the
source evidence boundary; the authors themselves reduce the result to the
fixed calendar rule below. Their futures series rolls around contract expiry,
whereas `XNGUSD.DWX` is a continuous Darwinex CFD. Q02 must therefore falsify,
not assume, transfer of the anomaly.

## Concept And Non-Duplicate Decision

The package is long only from the first tradable price after the Thursday D1
bar completes until the first tradable price after the Tuesday D1 bar
completes. In Darwinex broker-day terms this maps to entry on the opening tick
of the Friday D1 bar and exit on the opening tick of the Wednesday D1 bar.

The verdict is `NO_EXACT_MECHANIC_DUPLICATE` with
`KNOWN_RETURN_WINDOW_OVERLAP`:

- `QM5_12567_cum-rsi2-commodity` is a conditional RSI(2) pullback above
  SMA(200), exits on RSI recovery or five bars, and normally flattens Friday.
- `QM5_12818_xng-tue-prem` holds only the Tuesday D1 return; it does not hold
  Friday, the weekend, Monday, or the full source package.
- `QM5_12819_xng-thu-fade` is short only for the Thursday D1 return; it is the
  avoided interval here, not this long carry interval.
- `QM5_12806_xng-rev-weekend` opens independent Monday-long and Friday-short
  one-day trades; it neither enters Thursday close nor holds through Tuesday.
- XNG storage, weather-gap, monthly seasonality, trend, reversal, expiry and
  cross-asset baskets use event, price-state or relative-value triggers absent
  from this fixed weekly hold.

The combined package necessarily contains the Monday D1 long return already
sampled by pending `QM5_12806` and the Tuesday D1 long return already sampled
by pending `QM5_12818`. Its incremental exposures are the Friday session,
weekend gap and persistent multi-day lifecycle. The source's exact combined
Thursday-close/Tuesday-close rule is therefore a distinct mechanic, but this
card does not claim decorrelation from those pending siblings before Q02 and
later portfolio evidence.

## Markets And Timeframes

- Target: `XNGUSD.DWX`, magic slot 0, D1 host only.
- Decision cadence: one eligible entry per broker week.
- Entry proxy: Friday D1 open, immediately after Thursday D1 completion.
- Exit proxy: Wednesday D1 open, immediately after Tuesday D1 completion.
- Expected frequency: approximately 48 completed packages/year.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Runtime inputs: native MT5 broker calendar, D1 prices, ATR, spread, position
  state, deal history and terminal global state only.

## 4. Entry Rules

- Evaluate entries only on a new `XNGUSD.DWX` D1 bar.
- Require the current broker-calendar D1 bar to be Friday
  (`strategy_entry_dow=5`, Sunday=0), the executable proxy for Thursday close.
- Require the first tradable tick to arrive within the locked five-minute
  opening grace; prime late Friday attaches so they cannot enter mid-session.
- BUY at market; the strategy is long only.
- Require no same-magic open position and no earlier entry deal or persisted
  entry attempt in the same broker week.
- Persist the weekly attempt marker before news gating and order submission so
  a news block, restart or broker rejection cannot create a later package that
  week.
- Treat deal-history selection failure as a consumed weekly decision before
  failing closed, preventing restart-dependent recovery entries.
- Require a valid closed-bar ATR and a nonnegative spread no greater than
  `strategy_max_spread_points`.
- Set one frozen hard stop at `strategy_atr_sl_mult * ATR(strategy_atr_period)`
  below entry. No take-profit is authorized.

## 5. Exit Rules

- Close on the first tradable D1 opening tick after the Tuesday D1 bar has
  completed; normally this is the Wednesday D1 open
  (`strategy_exit_dow=3`, Sunday=0).
- If the normal Wednesday bar is absent, close on the next tradable D1 bar
  after the intended Tuesday-close boundary.
- Close after `strategy_max_hold_days=7` calendar days as a stale guard.
- The broker hard stop remains active throughout the package.
- No price target, signal reversal, trailing stop, break-even move, partial
  close, or discretionary exit.

## 6. Filters (No-Trade Module)

- Exact host guard: `XNGUSD.DWX`, D1, magic slot 0.
- Entry and exit weekdays are locked to Friday and Wednesday respectively.
- Parameter, broker time, ATR, price, spread and arithmetic checks fail closed.
- Framework kill switch and news-entry policy remain authoritative.
- News filtering blocks only new risk; Tuesday-close and stale exits continue.

## 7. Trade Management Rules

- One long position per magic and at most one attempt per broker week.
- Friday close is deliberately disabled because weekend and Monday/Tuesday
  exposure are load-bearing parts of the source rule.
- Lifecycle exits execute before the entry-news gate and remain restart-safe.
- No scale-in, pyramid, grid, martingale, adaptive fit, external runtime feed,
  banned indicator, or ML component.

## Parameters To Test

| parameter | default | source/card range | role |
|---|---:|---|---|
| `strategy_entry_dow` | 5 | [5] | locked Friday D1 open proxy for Thursday close |
| `strategy_exit_dow` | 3 | [3] | locked Wednesday D1 open proxy for Tuesday close |
| `strategy_entry_grace_minutes` | 5 | [5] | locked first-tradable opening tolerance; late attaches are rejected |
| `strategy_atr_period` | 20 | [14, 20, 30] | V5 frozen hard-stop estimate; source silent |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 4.5] | V5 frozen hard-stop distance; source silent |
| `strategy_max_hold_days` | 7 | [7] | stale guard only; normal hold is about five days |
| `strategy_max_spread_points` | 2500 | [1500, 2500, 3500] | XNG entry spread cap |

Entry/exit weekdays, long direction, weekly cadence, and weekend hold are
locked. Changing any of them creates a new strategy rather than a sweep.

## 9. Author Claims

"A weekly strategy incorporating these DOW effects involves taking a long position at the Thursday close and then closing that position at the Tuesday close." (Section 4, printed page 15)

## 10. Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 35.0` reflects Natural Gas tail risk and unhedged weekend
  gaps; it is not a source statistic.
- Expected frequency: approximately 45-52 packages/year.
- Risk class: high.
- Source silent on stop sizing; V5 `RISK_FIXED` requires a deterministic hard
  stop, whose impact must be measured rather than attributed to the paper.

## Kill Criteria

- Retire at Q02 if realized frequency is below five completed trades/year.
- Fail on zero trades, repeated `OnInit` failure, duplicate weekly entries,
  wrong weekday mapping, nondeterministic reruns, or risk-mode mismatch.
- Treat futures/CFD basis, broker-day alignment, weekend gaps, costs,
  expectancy and realized book correlation as falsification risks, never
  waiver grounds.
- Do not add RSI, trend, storage, weather, return-threshold or volatility-model
  gates after a weak baseline.

## 11. Strategy Allowability Check

- [x] Mechanical fixed calendar entry, exit, stop and stale guard.
- [x] No ML, GARCH runtime, banned indicator, grid, martingale or pyramiding.
- [x] Peer-reviewed full source with DOI and exact rule location.
- [x] `XNGUSD.DWX` D1 data and magic slot 0 are registered/available.
- [x] Expected frequency exceeds the five-trades/year Q02 floor.
- [x] Exact-mechanic dedup search is clean; partial return-window overlap with
  pending `QM5_12806`/`QM5_12818` is disclosed.
- [x] Friday-close exception is explicit and source-required.

## 12. Framework Alignment

- no_trade: exact symbol/D1/slot, locked weekday and parameter validation,
  spread cap, weekly deal/attempt guards.
- trade_entry: Friday D1-open long with frozen ATR hard stop.
- trade_management: Wednesday boundary and seven-day stale closes, evaluated
  before entry news gating.
- trade_close: `QM_TM_ClosePosition(..., QM_EXIT_STRATEGY)` plus broker stop.

`hard_rules_at_risk`:

- `friday_close`: disabled because the source requires a weekend hold; this is
  declared through the framework execution contract.
- `risk_mode_dual`: only a RISK_FIXED backtest setfile is authorized.
- `darwinex_native_data_only`: runtime uses only MT5-native CFD data; the
  paper's rolled futures results are lineage, not an external runtime feed.

## 13. Implementation Notes

- target_modules.no_trade: fail-closed XNG/D1/slot and locked parameter checks.
- target_modules.entry: restart-safe weekly Friday long, ATR hard stop.
- target_modules.management: first post-Tuesday D1 close and seven-day stale
  exits before the news-entry gate.
- target_modules.close: direct framework close reason plus server hard stop.
- estimated_complexity: small.
- estimated_test_runtime: one D1 XNG baseline only; smoke deferred at current
  CPU ceiling.
- data_requirements: standard native `.DWX` D1 history.

## Risk And Safety Boundary

The build may create one `RISK_FIXED` XNG backtest setfile only. It must not
create or modify a live setfile, `T_Live`, AutoTrading, deploy manifest,
T_Live manifest, portfolio gate, portfolio admission, or portfolio KPI code.

## 14. Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-19 | initial source-explicit XNG weekly calendar carry | Q01 | APPROVED |

## 15. Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-19 | APPROVED; R1-R4 PASS | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_20011_xng-thu-tue.md` |
| Q01 Build Validation | - | pending | - |
| Q02 Baseline Screening | - | pending enqueue | - |

## 16. Lessons Captured

- 2026-07-19: Source-level dedup must distinguish the combined weekend carry
  package from already-built single-weekday effects while disclosing the
  package's Monday/Tuesday return-window overlap.
