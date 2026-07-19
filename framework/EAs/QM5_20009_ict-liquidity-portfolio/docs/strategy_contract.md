# QM5_20009 ICT Liquidity Portfolio — frozen research contract

**EA ID:** 20009  
**Slug:** `ict-liquidity-portfolio`  
**Contract date:** 2026-07-19  
**Authorization:** OWNER-delegated by the explicit user governance override in the
2026-07-19 Codex session. This authorizes research/build/test work; it is not a
paid-challenge or live-deploy authorization.

## 1. Evidence boundary

This contract separates source statements from engineering choices. No result in
`Trades_some_icy_tea.xlsx` is treated as a realized trade result. The workbook is a
curated screenshot catalogue with strong survivorship and hindsight-label bias:
770 rows are labelled `Trade`, but there is no systematic date, stop, realized P/L,
or losing-signal universe. Its useful contribution is hypothesis frequency only.

Primary local inputs:

- `C:\Users\Administrator\Downloads\MQL5_Strategie_Spezifikation_some_icy_tea.docx`
- `C:\Users\Administrator\Downloads\Trades_some_icy_tea.xlsx`
  (SHA-256 `61e29a66c1a17511906020b4f6b99ea81b0693fb6c4e5b894df3d8fb2e231e70`)
- `D:\QM\reports\ict_intake\spec.txt`
- the approved/local ICT cards and existing EAs inspected in the 2026-07-19 inventory

Primary online sources:

- Michael J. Huddleston, *2022 ICT Mentorship Episode 2*:
  https://www.youtube.com/watch?v=tmeCWULSTHc
- Michael J. Huddleston, *2023 ICT Mentorship — ICT Silver Bullet Time Based
  Trading Model*: https://www.youtube.com/watch?v=tRq1hyGGtl4
- FTMO, *Trading Objectives*: https://ftmo.com/en/trading-objectives/
- MQL5 time semantics:
  https://www.mql5.com/en/docs/dateandtime/timegmt and
  https://www.mql5.com/en/docs/dateandtime/timetradeserver

The common testable hypothesis supported by the local corpus is:

> external/session liquidity sweep -> later closed-bar market-structure shift with
> displacement -> first retracement into the first post-shift FVG -> stop beyond the
> swept extreme -> nearest opposing external/session liquidity target.

This is a hypothesis to test, not a profitability claim.

## 2. Sleeve A — index intraday sweep/MSS/FVG

**Primary market/timeframe:** `NDX.DWX`, M5.  
**Transport market:** `GDAXI.DWX`, M5 (never used to tune the NDX parameters).

Rules are evaluated only from completed bars; orders execute on subsequent real
ticks.

1. Convert broker time to `America/New_York` with an explicit US-DST calendar.
   Tester `TimeGMT()` is not treated as true historical UTC.
2. Build the current New-York-day external range from 00:00 through 09:30 NY.
   This precise pool is an engineering formalization of the source's discretionary
   "old high/low / draw on liquidity" field.
3. Between 09:30 and 11:00 NY, one side of that range must be swept. Price must
   close back inside on the sweep bar or within two later completed M5 bars.
4. A subsequent completed bar — never the sweep bar — must close through the most
   recent pre-sweep confirmed 3-bar swing on the opposite side. Its body must be at
   least `index_displacement_atr` times ATR(14).
5. The first directionally matching three-candle FVG completed after that MSS and
   between 10:00 and 11:00 NY is eligible. A limit order is placed at the FVG edge
   first encountered by a retracement (not an invented mandatory midpoint).
6. Stop: beyond the sweep extreme by `index_stop_buffer_atr * ATR(14)`.
7. Target: the opposite edge of the 00:00-09:30 range, i.e. the nearest frozen
   opposing session-liquidity pool. Reject geometry below `index_min_rr`.
8. The pending order expires at 11:00 NY. Maximum one filled trade per NY day.
   Any open trade is flat by 16:00 NY or the framework Friday close.

Source-derived fields: liquidity run, later 3-bar swing break/MSS, first FVG trade,
stop above/below the swept extreme, nearest opposing liquidity, 10:00-11:00 NY
entry window. Engineering fields: the 00:00-09:30 range definition, two-bar reclaim,
ATR displacement threshold/buffer, M5 port, one-trade/day, and 16:00 flat.

Frozen development neighbourhood (one-at-a-time, not a Cartesian search):

| Variant | displacement ATR | minimum FVG ATR | minimum R |
|---|---:|---:|---:|
| baseline | 1.00 | 0.05 | 1.25 |
| disp-low / disp-high | 0.80 / 1.20 | 0.05 | 1.25 |
| fvg-low / fvg-high | 1.00 | 0.00 / 0.10 | 1.25 |
| rr-low / rr-high | 1.00 | 0.05 | 1.00 / 1.50 |

## 3. Sleeve B — FX weekly liquidity sweep

**Primary market/timeframe:** `GBPUSD.DWX`, H1.  
**Transport market:** `USDJPY.DWX`, H1. `XAUUSD.DWX` is exploratory only because
the screenshot corpus contains just 26 gold examples.

1. Reconstruct the complete Monday 00:00-24:00 New-York-time high/low from closed
   H1 bars on every evaluation. No restart-dependent incremental state is allowed.
2. Tuesday-Friday, the penultimate completed bar must penetrate one Monday boundary
   by at least `weekly_liq_pct` and no more than `weekly_max_wick_pct` of that level.
3. The latest completed bar must close back inside the Monday range. The next tick
   enters a market fade: high sweep -> short; low sweep -> long.
4. Stop: beyond the sweep extreme by `weekly_stop_pct` of price.
5. Baseline target is the opposite Monday boundary. The predeclared local-source
   challenger uses the larger of 3.5R and 1.30 Monday ranges. Target policy is
   selected on development/walk-forward data and frozen before holdout.
6. Reject geometry below `weekly_min_rr`. Maximum one filled trade per NY week.
7. At +1.5R or after 24 elapsed H1 bars, move the stop to +0.1R. Force flat Friday
   13:30 NY, with the framework Friday close as a backstop.

The Monday-box realization comes from the strongest reusable local liquidity-sweep
EA (`QM5_10706`) but fixes its restart loss, pre-send weekly lock, next-bar fill/R
anchor, fixed broker-time Friday exit, and management-starvation defects.

Frozen development neighbourhood (one-at-a-time):

| Variant | min penetration | max penetration | stop padding |
|---|---:|---:|---:|
| baseline | 0.00020 | 0.00250 | 0.00020 |
| liq-low / liq-high | 0.00010 / 0.00030 | 0.00250 | 0.00020 |
| wick-low / wick-high | 0.00020 | 0.00200 / 0.00300 | 0.00020 |
| stop-low / stop-high | 0.00020 | 0.00250 | 0.00010 / 0.00030 |

## 4. Data partitions and anti-overfit rules

No parameter or entry/exit rule may change after the final configuration hash is
frozen. Any change invalidates all downstream evidence.

| Sleeve | Development | selection/WF | validation | sealed final holdout |
|---|---|---|---|---|
| NDX M5 | 2021-2022 | 2023-2024 | 2025 | 2026-01-01..2026-06-30 |
| GBPUSD H1 | 2017-2021 | 2022-2023 | 2024-2025 | 2026-01-01..2026-06-30 |

`GDAXI.DWX` and `USDJPY.DWX` are transport tests. They cannot be used to repair a
failed primary-market holdout. All MT5 tests use Model 4 / real ticks, registered
`.DWX` symbols, explicit costs, deterministic duplicate runs, and untouched gate
thresholds. Results are reported gross and cost-adjusted; zero-commission reports
cannot support a net-profitability claim.

## 5. FTMO boundary

The EA must fail closed outside the tester unless an exact FTMO governor policy,
challenge instance ID, fresh governor heartbeat, percent-risk mode, and USD hedging
account are present. Open-position management and mandatory exits run even when new
entries are blocked by news or the governor.

Historical profitability is not a promise of passing. A paid-challenge-ready claim
requires synchronized joint-equity replay including floating P/L, commission, swap,
CE(S)T midnight resets, current FTMO 1-Step/2-Step product semantics, daily and total
loss rules, targets, minimum trading days, and (for 1-Step) Best Day. Closed-daily or
bar-only approximations remain research screens.

