---
ea_id: QM5_10391
slug: et-uptick-limit
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "abogdan, Strategy that works well for MSFT, Elite Trader, 2004-02-09, https://www.elitetrader.com/et/threads/strategy-that-works-well-for-msft.28280/"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/order-flow-proxy]]"
  - "[[concepts/limit-entry]]"
  - "[[concepts/mean-reversion]]"
indicators: [Tick Direction Proxy]
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX]
period: H3
expected_trade_frequency: "On 180-minute bars the tick-bias proxy can trigger frequently; conservative estimate 90 trades/year/symbol after CFD proxy and one-position filters."
expected_trades_per_year_per_symbol: 90
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; Elite Trader URL and handle `abogdan` provide full lineage."
r2_mechanical: PASS
r2_reasoning: "M1 close-direction proxy calculation, limit-entry placement, entry-price target, and bar-count failsafe exit are all deterministic."
r3_data_available: PASS
r3_reasoning: "M1 close-direction proxy substitutes native equity uptick/downtick fields, making the strategy testable on SP500.DWX, NDX.DWX, and WS30.DWX."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed rate/K parameters, single-position conversion; no ML, adaptive PnL-based logic, grid, or martingale."
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 source URL/handle present; R2 uptick/downtick proxy limit entries and entry-price exits mechanical with ~90 trades/year/symbol; R3 testable on SP500.DWX backtest and NDX/WS30 CFDs via M1 proxy; R4 fixed single-position non-ML rules."
---

# Elite Trader Uptick Downtick Limit Mean Reversion

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/strategy-that-works-well-for-msft.28280/
- Author / handle: `abogdan`.
- Date: 2004-02-09.
- Location: post #1 gives EasyLanguage using `UpTicks`, `DownTicks`, close-offset limit entries, and entry-price limit exits.

## Mechanik

### Entry
- Source timeframe: 180-minute bars on MSFT / QQQ with extended hours.
- V5 port: H3 on index CFDs using an OHLC-compatible tick-direction proxy:
  - `UpTicksProxy = count of intrabar M1 closes above prior M1 close`.
  - `DownTicksProxy = count of intrabar M1 closes below prior M1 close`.
- If flat and `UpTicksProxy > DownTicksProxy`, place a buy limit for next bar at `Close - Rate`.
- If flat and `UpTicksProxy < DownTicksProxy`, place a sell-short limit for next bar at `Close + Rate`.
- Default `Rate = 0.14% of close` because the source value `0.14` was stock-price absolute.

### Exit
- Long exit: limit at `EntryPrice + Rate / K`.
- Short exit: limit at `EntryPrice - Rate / K`.
- Default `K = 1`.
- V5 failsafe: exit after 8 bars if target not reached.

### Stop Loss
- Source does not specify a stop.
- V5 protective stop: 1.5 times `Rate`, minimum four spreads.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Cancel unfilled limit order after one bar.
- Do not trade if the M1 proxy has fewer than 30 valid child bars inside the H3 parent bar.

## Concepts
- [[concepts/order-flow-proxy]] - uses uptick/downtick imbalance or a CFD OHLC proxy.
- [[concepts/limit-entry]] - enters by fading away from the close with limit orders.
- [[concepts/mean-reversion]] - target is a fixed move back from entry.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL plus visible handle `abogdan`. |
| R2 Mechanical | PASS | Source code specifies entry and exit orders; V5 defines the CFD tick proxy. |
| R3 DWX-testbar | UNKNOWN | Native `UpTicks`/`DownTicks` may not exist in DWX history; proposed M1 close-direction proxy makes it testable but weaker than OHLC-native rules. |
| R4 No ML | PASS | Fixed parameters, one-position conversion, no ML/adaptive/grid/martingale logic. |

## R3
Primary P2 basket: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- The author says the system worked well for them on 180-minute bars in MSFT and QQQ.
- The source uses `UpTicks > DownTicks` for buy-limit bias and `UpTicks < DownTicks` for sell-limit bias.

## Parameters To Test
- Rate: 0.05%, 0.10%, 0.14%, 0.20% of close.
- K: 0.5, 1.0, 1.5.
- Parent period: H1, H3, H4.
- Max hold: 4, 8, 12 bars.
- Proxy: M1 close-direction count, M5 close-direction count.

## Initial Risk Profile
Porting risk is high because the original uses platform uptick/downtick fields from equities. This is still a bounded, deterministic candidate if treated as an index-CFD proxy experiment.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.
