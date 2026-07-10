---
ea_id: QM5_13114
slug: wti-roc14-xtrm
type: strategy
strategy_id: GURRIB-WTI-ROC14-2024_S01
source_id: GURRIB-WTI-ROC14-2024
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citation: "Gurrib, Starkova, and Hamdan (2024), Trading Momentum in the U.S. Crude Oil Futures Market, International Journal of Energy Economics and Policy 14(5), 593-604, DOI 10.32479/ijeep.16520."
source_citations:
  - type: peer_reviewed_paper
    citation: "Gurrib, Ikhlaas; Starkova, Olga; and Hamdan, Dalia (2024). Trading Momentum in the U.S. Crude Oil Futures Market. International Journal of Energy Economics and Policy 14(5), 593-604."
    location: "Full paper, especially Sections 4-6, pp. 598-602; DOI https://doi.org/10.32479/ijeep.16520; published PDF https://www.econjournals.com/index.php/ijeep/article/download/16520/8218"
    quality_tier: B
    role: primary
  - type: official_exchange_page
    citation: "CME Group. WTI Crude Oil Futures."
    location: "https://www.cmegroup.com/markets/energy/wti-crude-oil-futures.html"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/GURRIB-WTI-ROC14-2024]]"
concepts:
  - "[[concepts/long-horizon-energy-overreaction]]"
  - "[[concepts/monthly-extreme-crossing]]"
  - "[[concepts/persistent-contrarian-state]]"
indicators:
  - "[[indicators/month-end-close]]"
  - "[[indicators/rate-of-change]]"
  - "[[indicators/atr]]"
strategy_type_flags: [signal-reversal-exit, atr-hard-stop, time-stop, symmetric-long-short, news-blackout]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13114_WTI_ROC14_XTRM_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly packages while a source-defined ROC-14 extreme state is active; estimate 6-12 completed packages/year after warm-up, before Q02 validation."
expected_trades_per_year_per_symbol: 9
expected_pf: 1.03
expected_dd_pct: 28.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, cfd_futures_basis, enhancement_doctrine]
g0_approval_reasoning: "Mission-directed G0 2026-07-10: R1 peer-reviewed open 2024 WTI paper plus official CME lineage (B due sparse/outlier-sensitive evidence); R2 locked monthly ROC14 +/-40% contrarian crossing state and deterministic V5 packages; R3 native XTIUSD.DWX D1; R4 no ML/banned/external/grid/martingale; dedup C"
---

# WTI 14-Month ROC Extreme-Crossing Reversal

## Hypothesis

Very large long-horizon WTI moves can exhaust when slow physical supply and
demand adjustment meets crowded financial positioning. This card tests a
published end-of-month rule: an outward crossing of +40% on the 14-month rate
of change establishes a short state, while an outward crossing of -40%
establishes a long state. The most recent extreme crossing remains authoritative
until the opposite extreme crossing.

The sleeve adds direct crude-oil exposure to a certified book concentrated in
XAU, SP500, NDX, and XNG. Economic distinctness is plausible, not certified;
Q09 alone may establish realized portfolio orthogonality.

## Source

Primary: Gurrib, Starkova, and Hamdan (2024), "Trading Momentum in the U.S.
Crude Oil Futures Market", *International Journal of Energy Economics and
Policy* 14(5), 593-604, DOI `10.32479/ijeep.16520`. The complete open published
paper was reviewed. CME Group's WTI product page supplies official benchmark
lineage without changing the trading rule.

The paper selects a 14-month ROC from 9-14 month candidates, fixes overbought
and oversold levels at +40% and -40%, and pairs each position with the next
opposite signal. It reports only eight completed positions in its 2004-2024
sample, four losing positions from 2017 onward, and strong dependence on a
2009 outlier. Those weaknesses are binding falsification context.

## Concept And Non-Duplicate Decision

At each broker-month transition, reconstruct completed WTI month-end closes
from D1 history. Compute the latest 14-month ROC and the immediately preceding
month's 14-month ROC. Crossing outward through +40% records a short state;
crossing outward through -40% records a long state. Scan the bounded historical
month-end series chronologically so a restart recovers the last valid state
without a file, API, fitted model, or future information.

This is deliberately different from:

- `QM5_12603_wti-tsmom12m`, `QM5_12616_tsmom-9m-commodity-xtiusd`, and
  `QM5_13100_wti-dmac16`, which follow return sign, multi-horizon agreement, or
  a price-versus-six-month-mean neutral band. This card is contrarian and acts
  only on a source-fixed long-horizon extreme crossing.
- `QM5_12621_comm-reversal-4wk-xtiusd`,
  `QM5_12594_yang-wti-reversal`, and `QM5_12979_wti-6m-reversal`, which fade
  20-, 63-, or 120-D1 moves using weekly/monthly threshold checks plus short
  holds, SMA/ATR stretch, confirmation, or return-zero exits. This card uses
  completed month ends, a locked 14-month horizon, locked +/-40% levels, and a
  persistent opposite-extreme state.
- WTI event, inventory, refinery, OPEC, COT, production, roll, expiry,
  weekday, month-of-year, channel, XTI/XNG, WTI/Brent, oil/metal, RSI, and
  volatility-state builds. None of those mechanisms is present.

Pre-allocation repository dedup verdict: `CLEAN` for slug
`wti-roc14-xtrm`, strategy ID `GURRIB-WTI-ROC14-2024_S01`, and the full
14-month +/-40% extreme-crossing fingerprint.

## Markets And Timeframe

- Target and host: `XTIUSD.DWX`, magic slot 0.
- Host timeframe: D1; signal sampling and packages are monthly.
- Expected frequency: 6-12 completed monthly packages per active-state year
  after warm-up. Q02 must measure the full-window rate.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Runtime data: native MT5 D1 OHLC, ATR, spread, calendar, and position state.

## Rules

The source state is deterministic: use completed month-end closes, record a
short target only when 14-month ROC crosses outward through +40%, record a long
target only when it crosses outward through -40%, and retain the latest target
until the opposite crossing. The V5 carrier rolls that target into one bounded
package per broker month.

## 4. Entry Rules

- Evaluate only on the first new `XTIUSD.DWX` D1 bar of a broker month.
- Reconstruct up to `strategy_state_history_months=360` completed month-end
  closes, newest first, using D1 bars only.
- Require at least `strategy_roc_months + 2` completed month ends.
- For each chronological month with sufficient history, compute
  `roc14 = close_month / close_month_minus_14 - 1`.
- When the prior month's ROC is below +40% and the latest ROC is at or above
  +40%, record target short.
- When the prior month's ROC is above -40% and the latest ROC is at or below
  -40%, record target long.
- Retain the last non-zero target between crossings. Remain flat if no crossing
  exists in the available bounded history.
- At a month transition, close the prior package before considering the new
  package. If the target is non-zero, open one market position in that target.
- Reject wrong symbol/timeframe/slot, duplicate-month entry, invalid history,
  invalid arithmetic, an existing magic position, excessive spread, or invalid
  ATR.
- Every entry receives a frozen D1 ATR hard stop and no take-profit.

## 5. Exit Rules

- Close the prior monthly package at the next broker-month transition. If the
  retained target remains unchanged, a new package may open after the close.
- If an opposite extreme crossing occurs, close the old side and allow one
  opposite package on that same monthly decision bar.
- Close any package older than `strategy_max_hold_days=35` as a stale safety
  guard.
- Broker ATR stop remains active throughout the month.
- Friday close is disabled for this backtest card because weekly flattening
  would replace the source's monthly holding cadence.

## 6. Filters (No-Trade Module)

- Exact `XTIUSD.DWX` D1 host and magic slot 0.
- Parameter, history, price, ROC, ATR, spread, and calendar checks fail closed.
- Standard V5 kill switch and news entry compliance remain authoritative.
- No futures chain, COT, inventory, EIA, OPEC, volume, open interest, CSV,
  API, external feed, or ML model.

## 7. Trade Management Rules

- One position per magic/symbol and one accepted entry per broker month.
- No take-profit, trailing stop, break-even move, partial close, scale-in,
  grid, martingale, pyramiding, or adaptive PnL rule.
- Monthly rollover and the 35-day stale guard are the only active management
  actions beyond the frozen broker ATR hard stop.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_roc_months` | 14 | [14] | source-selected monthly ROC horizon |
| `strategy_extreme_pct` | 40.0 | [40.0] | source-selected symmetric extreme |
| `strategy_state_history_months` | 360 | [240, 360] | bounded restart-state reconstruction |
| `strategy_atr_period` | 20 | [14, 20, 30] | V5 D1 hard-stop volatility estimate |
| `strategy_atr_sl_mult` | 4.0 | [3.0, 4.0, 5.0] | V5 frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale guard around monthly rollover |
| `strategy_max_spread_points` | 1500 | [1000, 1500, 2500] | entry spread cap |

The 14-month horizon, +/-40% crossings, contrarian direction, monthly package
cadence, and persistent target map are locked. Narrower thresholds, MA filters,
ROC-or-MA signals, daily ROC, trend-direction substitution, or post-hoc entry
confirmation require a new card and full rerun.

## Author Claims

The authors conclude: "Therefore, the use of ROC-14 model without MA is
recommended for the crude oil futures market." (Section 6, p. 602.)

That is source lineage, not a QM forecast. The same paper reports low Sharpe,
outlier sensitivity, and four losing positions after 2017. Q02 and later gates
are the only evidence for this CFD port.

## Initial Risk Profile

- `expected_pf: 1.03` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 28.0` reflects sparse state changes, crude gaps, and the
  paper's disclosed weak recent trades.
- Risk class: high. The continuous CFD differs from the source futures series,
  and monthly fixed-risk packages differ from one continuous source position.
- Backtests use `RISK_FIXED=1000`; no volatility-target or percent-risk override.

## Strategy Allowability Check

- [x] R1 reputable source: peer-reviewed 2024 paper with DOI/full published
  text plus official CME benchmark supplement; primary evidence rated B due to
  sparse trades and disclosed fragility.
- [x] R2 mechanical: fixed month-end reconstruction, 14-month ROC, +/-40%
  crossings, persistent state, monthly rollover, ATR stop, and stale exit.
- [x] R3 testable: registered `XTIUSD.DWX` D1 data only.
- [x] R4 compliant: no ML, banned indicator, adaptive fit, external runtime
  feed, grid, martingale, pyramiding, or multi-position magic.
- [x] Non-duplicate: explicit source-defined 14-month extreme-crossing state,
  not existing short/medium reversal or slow trend logic.

## Framework Alignment

- no_trade: exact XTI/D1/slot guard, parameter domains, month transition,
  history/arithmetic validity, spread cap, and duplicate-month guard.
- trade_entry: recover the most recent 14-month ROC extreme-crossing state and
  open one monthly package with a frozen ATR hard stop.
- trade_management: close at month rollover or the 35-day stale limit.
- trade_close: package rollover/opposite-state close through the framework;
  broker ATR stop remains the intramonth catastrophe exit.

## Risk And Safety Boundary

The build creates one `RISK_FIXED` backtest setfile only. It does not create or
modify a live setfile, `T_Live`, AutoTrading, deploy manifest, T_Live manifest,
portfolio admission, portfolio KPI, or portfolio gate.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial source-backed WTI ROC-14 extreme-crossing build | G0 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | PENDING | this card |
