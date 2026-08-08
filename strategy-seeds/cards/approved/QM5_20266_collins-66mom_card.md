---
ea_id: QM5_20266
slug: collins-66mom
type: strategy
strategy_id: SRC08_S01_XTI
source_id: SRC08
created: 2026-08-08
created_by: Research
last_updated: 2026-08-08
source_citation: "Collins, Art (2006), Beating the Financial Futures Market, John Wiley & Sons, Chapter 41 pp. 177-179 and Appendix Table 41.3 p. 232."
source_citations:
  - type: book
    citation: "Collins, Art. Beating the Financial Futures Market: Combining Small Biases into Powerful Money Making Strategies. John Wiley & Sons, 2006."
    location: "Chapter 41, printed pp. 177-179; Appendix Table 41.3, printed p. 232."
    quality_tier: A
    role: primary
sources:
  - "[[sources/SRC08]]"
concepts:
  - "[[concepts/commodity-structural-momentum]]"
  - "[[concepts/close-location-geometry]]"
indicators:
  - "[[indicators/price-range-arithmetic]]"
strategy_type_flags: [commodity-trend, close-location-momentum, stop-entry, formula-hard-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
period: D1
expected_trade_frequency: "D1 WTI day-only stop entries; estimate 15-40 completed trades/year after CFD spread, news, and Friday-close guards."
expected_trades_per_year_per_symbol: 28
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_pf: 1.1
expected_dd_pct: 22.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, one_position_per_magic_symbol, enhancement_doctrine]
g0_approval_reasoning: "OWNER 2026-08-08 commodity sleeve mission; R1 one Wiley source, R2 source-exact deterministic 9-day 0.66/1.32 geometry, R3 registered XTIUSD.DWX D1 port, R4 one-position ML-free native-price implementation."
---

# Collins 9-Day 66 Percent Momentum - WTI

## 1. Source

The single source is Art Collins (2006), *Beating the Financial Futures
Market*, John Wiley & Sons, Chapter 41 printed pages 177-179 and Appendix
Table 41.3 on printed page 232. The complete bounded section and formula were
re-read from the OWNER-approved local `SRC08` source packet.

The source tests the rule on full-sized S&P and other financial futures. It
does not report WTI evidence. This card therefore treats `XTIUSD.DWX` as an R3
port and falsification carrier. No source profit factor, return, drawdown,
accuracy, frequency, or futures-to-CFD equivalence is imported into the prior.

## 2. Concept

The last close's location inside its 9-day high-low envelope determines which
direction has more room for an early momentum expansion. A close nearer the
9-day low arms an upside stop a fixed fraction above the next open; a close
nearer the 9-day high arms the symmetric downside stop. The hard stop comes
from the same two high/low distances, rather than from an unrelated signal.

The WTI carrier adds direct crude-oil supply/demand exposure to a certified
book concentrated in XAU, SP500, NDX, and XNG. Different underlying economics
are a hypothesis only. Q09 owns any later decorrelation claim.

## 3. Markets & Timeframes

- Target symbol: `XTIUSD.DWX` only.
- Host and signal timeframe: D1.
- Decision cadence: once on each newly observed broker D1 bar.
- Runtime data: Darwinex MT5 OHLC, quotes, spread, broker constraints, and
  framework position/order state only.
- Backtest risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## 4. Entry Rules

On a new D1 bar, use only the nine completed bars at shifts 1 through 9:

```text
C  = close[1]
H9 = max(high[1..9])
L9 = min(low[1..9])
XH = H9 - C
XL = C - L9
XX = max(XH, XL)
O  = open[0]
```

- Require finite positive prices, `H9 > L9`, `XH > 0`, `XL > 0`, and
  `XH != XL`.
- Long setup: if `XH > XL`, arm a BUY STOP at
  `O + strategy_entry_fraction * XL`.
- Short setup: if `XL > XH`, arm a SELL STOP at
  `O - strategy_entry_fraction * XH`.
- Default `strategy_lookback_d1=9` and `strategy_entry_fraction=0.66` are the
  source rule.
- Long hard SL: pending entry price minus
  `strategy_stop_fraction * XX`.
- Short hard SL: pending entry price plus
  `strategy_stop_fraction * XX`.
- Default `strategy_stop_fraction=1.32` is exactly twice the source entry
  fraction.
- The pending entry expires after 24 hours and is canceled before a genuinely
  new D1 bar is armed.
- Consume the current D1 bar before spread, news, quote, broker-distance, or
  send gates. Never retry the same bar after rejection, failure, stop-out, or
  EA restart.

## 5. Exit Rules

- The frozen formula hard stop attached to the filled pending order is the
  primary loss exit.
- While long, if a later completed-bar state has `XL > XH`, calculate that
  day's source short trigger `open[0] - 0.66 * XH`; flatten when bid reaches or
  crosses it.
- While short, if a later completed-bar state has `XH > XL`, calculate that
  day's source long trigger `open[0] + 0.66 * XL`; flatten when ask reaches or
  crosses it.
- A source reversal is flatten-only in this V5 port. Do not hedge, double the
  volume, or open the opposite side in the same tick.
- Close after `strategy_max_hold_bars=20` completed D1 bars as a stale-state
  guard.
- Friday close remains enabled. There is no take-profit or trailing stop.

## 6. Filters (No-Trade Module)

- Block any symbol/timeframe other than `XTIUSD.DWX` D1.
- Require magic slot 0 and valid fixed parameters.
- Skip incomplete or non-finite 9-day geometry.
- Skip entries above `strategy_max_spread_points=1000`.
- Require the pending entry and hard stop to exceed the broker stop level plus
  `strategy_min_stop_points=10`.
- Framework kill switch, two-axis news entry gate, and Friday-close controls
  remain active. News blocks new entries only, never management or exits.

## 7. Trade Management Rules

- One open position or one pending entry for this magic/symbol.
- One arm attempt per broker D1 bar, persisted through terminal Global
  Variables for restart invariance.
- No pyramiding, grid, martingale, averaging, partial close, break-even move,
  trailing stop, discretionary override, or adaptive sizing.
- Cancel stale pending entries at the next D1 transition and at the Friday
  close boundary.

## 8. Parameters To Test

- `strategy_lookback_d1`: default 9; declared range [7, 9, 12].
- `strategy_entry_fraction`: default 0.66; declared range [0.50, 0.66, 0.75].
- `strategy_stop_fraction`: default 1.32; declared range [1.00, 1.32, 1.50].
- `strategy_pending_expiry_hours`: default 24; fixed for the baseline.
- `strategy_max_hold_bars`: default 20; declared range [10, 20, 30].
- `strategy_max_spread_points`: default 1000; declared range [700, 1000, 1500].
- `strategy_min_stop_points`: default 10; fixed broker-safety floor.

Q02 uses only the source defaults. Any later sweep is limited to the declared
values; no post-result carrier or rule rescue is authorized.

## 9. Author Claims

The source describes the rule as a longer-term daily momentum method whose
entries, exits, and reversals share one price-location principle. Its reported
performance belongs to the source's S&P sample and is not a WTI expectation.

## 10. Initial Risk Profile

- `expected_pf: 1.10` is a conservative sequencing prior, never a gate.
- `expected_dd_pct: 22.0` is a conservative sequencing prior.
- Expected frequency: 15-40 completed WTI trades/year; central prior 28.
- Risk class: high because WTI gaps, CFD roll/basis behavior, and repeated
  false expansions can defeat the source geometry.
- Backtest sizing is framework `RISK_FIXED`; the hard stop is mandatory on
  every entry.

## 11. Strategy Allowability Check

| Gate | Verdict | Reason |
|---|---|---|
| R1 | PASS | One OWNER-approved Wiley book source with exact chapter and appendix locations. |
| R2 | PASS | Fixed 9-day high/low arithmetic, strict side rule, stop-entry formula, hard stop, reversal flatten, and stale exit. |
| R3 | PASS | `XTIUSD.DWX` and D1 history are registered; source-to-CFD porting is explicitly allowed. |
| R4 | PASS | Deterministic price arithmetic, one position per magic, no ML, external feed, grid, or martingale. |

## 12. Framework Alignment

- no_trade: symbol/timeframe, slot, parameter, history, spread, and broker
  distance guards.
- trade_entry: one day-only pending stop from completed 9-day geometry.
- trade_management: pending-order lifecycle and 20-D1-bar stale guard.
- trade_close: frozen formula SL, opposite-trigger flatten, and Friday close.

`modules_used: [no_trade, trade_entry, trade_management, trade_close]`

`hard_rules_at_risk: [friday_close, one_position_per_magic_symbol, enhancement_doctrine]`

## 13. Implementation Notes

`target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal,
Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]`

The EA label must be `QM5_20266_collins-66mom`, use magic slot 0 via
`QM_Magic(20266, 0)`, retain the `.DWX` symbol, and create no live setfile.

## 14. Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-08 | OWNER-authorized WTI specialization of unallocated SRC08_S01 draft | G0 | APPROVED |

## Review Focus

Verify shifts 1..9 exclude the live bar, `XH > XL` maps to the long side,
pending levels use the current D1 open, `XX` is frozen into the hard stop, and
restart handling cannot re-arm a consumed D1 bar. This edge adds outright WTI
momentum exposure, not another index, metal, XNG, ratio, event-feed, moving
average, or channel-breakout signal.

## Falsification

Retire if Q02 produces fewer than five completed trades/year, fails governed
economics, exhibits zero-trade implementation defects after one bounded
recovery, or cannot preserve formula stops. Later portfolio rejection remains
binding if the realized WTI stream is not sufficiently distinct from the
certified book.

## Hypothesis

A WTI close near one side of its completed 9-day range can precede a stop-entry
momentum expansion away from the next D1 open; the paired 0.66/1.32 geometry
may capture crude trends without reusing the book's index, metal, or XNG logic.

## Rules

Use completed D1 shifts 1..9, arm the source-side day-only pending stop once,
attach the source-coupled hard stop, flatten on an opposite source trigger or
after 20 completed bars, and keep Friday close enabled.

## Risk

Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1` for Q02.
No live artifact, portfolio-gate change, deploy manifest, `T_Live` action, or
AutoTrading action is authorized.
