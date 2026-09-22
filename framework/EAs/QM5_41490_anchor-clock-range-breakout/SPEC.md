# QM5_41490 anchor-clock range-breakout research instrument

- **EA ID:** QM5_41490
- **Slug:** `anchor-clock-range-breakout`
- **Type:** research instrument
- **Source:** `QM-RESEARCH-2026-0013` (`be46ba59baca625ee17711b44963a53ae9bc3de1bfccba4e118762e1ad897218`)
- **Parent mechanics:** `QM5_13213_balke-gmt3-range-breakout`
- **Hardened OCO reference:** `QM5_41485_ny-preopen-range-breakout-jpy`
- **Task:** `955537dd-63d2-4f84-a1b1-c4d2499b78c4`
**Status:** build-only research instrument; no roster, FTMO, pipeline, deployment, T_Live, or AutoTrading authority

## 1. Mechanical contract

- Runtime/decision timeframe is M30. Entry evaluation is gated by
  `QM_IsNewBar(_Symbol, PERIOD_M30)`; pending-order reconciliation, trailing,
  and time exits execute per tick.
- Every strategy bar is a complete 60-minute grid bar assembled from two exact
  closed M30 halves. Offset 0 represents `hh:00..hh+1:00`; offset 30 represents
  `hh:30..hh+1:30`. A missing half invalidates the setup.
- Range high/low cover the configured completed grid bars from the configured
  range start to range end. The interval must equal `range_bars * 60` minutes.
- ATR(14) is the simple mean of true range on the same grid. Reject a range
  narrower than 0.4 ATR or wider than 2.5 ATR.
- At the first news-eligible M30 opportunity in the half-open retry window,
  submit buy-stop at range high with stop loss at range low and sell-stop at
  range low with stop loss at range high. There is no take profit.
- Both send outcomes are retained. If exactly one send succeeds, cancel that
  leg and flatten any race fill. The first fill removes the peer. Persistent
  selected-clock day state permits one setup attempt and no re-entry that day.
- Placement is subject to mandatory high-impact PRE30/POST30 news blackout and
  the DXZ compliance profile. Stale-news maximum is 336 hours and fails closed.
  News never suspends management of an existing position.
- After favorable movement reaches 1.0 times the current open-to-stop distance,
  improve the stop to the two latest complete grid bars. At flat time, close
  positions and remove pending orders on the first available tick. Framework
  Friday close may act earlier.

## 2. Clock inputs

`anchor_clock` is a true runtime enum:

| numeric | enum | interpretation |
|---:|---|---|
| 0 | `SERVER_RAW` | supplied wall-clock fields are raw broker/server time |
| 1 | `GMT3_EQUIVALENT` | broker time is converted with `QM_BrokerToUTC`, then projected to fixed UTC+3 |
| 2 | `UTC` | broker time is converted with `QM_BrokerToUTC` and used as UTC |

Clock-defined instants are converted back to broker time with
`QM_UTCToBroker`. The fixed GMT+3 A anchor 06:00/18:00 therefore maps to raw
DXZ 05:00/17:00 in winter and 06:00/18:00 in summer.

The following are bounded inputs rather than compiled cell constants:

| input | valid contract |
|---|---|
| `strategy_range_start_hour/minute` | same-day 00:00..23:59; minute equals grid offset |
| `strategy_range_end_hour/minute` | after start and before flat; minute equals grid offset |
| `strategy_flat_hour/minute` | same selected-clock day, after range end |
| `strategy_grid_offset_minutes` | 0 or 30 for exact two-M30 reconstruction |
| `strategy_range_bars` | 1..24 and exactly matches start/end duration |
| `strategy_news_retry_window_minutes` | 1..240 |
| `strategy_atr_period` | 2..100 |
| `strategy_range_scan_bars` | at least twice the required grid-bar count |

`OnInit` validates these general relations but does not freeze A2, A3, A4, a
single clock enum, or one anchor. It emits `INIT_OK` only after all framework
and input initialization succeeds.

## 3. Governed symbols and magic slots

The source has no tradable symbol literal; the chart symbol drives execution.

| slot | symbol | magic | present batch |
|---:|---|---:|---|
| 0 | `USDJPY.DWX` | 414900000 | A3 and A4 |
| 1 | `NZDJPY.DWX` | 414900001 | A2 |
| 2 | `EURUSD.DWX` | 414900002 | future F1/F2 only; no preset or Q02 row in this batch |

## 4. Exact falsification cell mapping

All three cells use M30, `anchor_clock=1`, range end 06:00, flat 18:00,
grid offset 0, retry 60, ATR 14, width band 0.4-2.5, trail 1.0, scan 36,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, news temporal 3, news compliance 1,
and stale maximum 336. Tester window: 2018-07-02 through 2022-12-31.

| set file | cell | symbol/slot | range | N | harness n | harness E[R] | PF | DD |
|---|---|---|---|---:|---:|---:|---:|---:|
| `...NZDJPY.DWX_M30_A2_backtest.set` | A2 | NZDJPY.DWX / 1 | 04:00-06:00 | 2 | 970 | +0.0570 | 1.122 | 21.00R |
| `...USDJPY.DWX_M30_A3_backtest.set` | A3 | USDJPY.DWX / 0 | 03:00-06:00 | 3 | 893 | +0.0675 | 1.161 | 21.87R |
| `...USDJPY.DWX_M30_A4_backtest.set` | A4 | USDJPY.DWX / 0 | 02:00-06:00 | 4 | 821 | +0.0753 | 1.184 | 18.56R |

There is exactly one preset per requested cell. A3 and A4 intentionally share
the governed USDJPY symbol slot while remaining distinct frozen experiments.

## 5. Comparison labels

- `EQUIVALENT`: valid like-for-like Q02 row; trade count within 15%, absolute
  E[R] difference no more than 0.03R, and absolute PF difference no more than
  0.10.
- `HARNESS_OVERSTATES`: valid row misses an equivalence bound and the harness
  is more favorable on the failed measure.
- `UNKNOWN`: absent/invalid row or unbound execution facts.

These are research-comparison labels only. Pipeline verdicts may be derived
only from pipeline evidence.

## 6. Risk and exclusions

All presets use fixed backtest risk greater than zero and percentage risk zero.
There is no scaling in, adverse adding, martingale, strategy grid trading,
learned model, parameter optimization, or live configuration. The account
governor—not this EA—owns the FTMO 5% daily-loss and 10% total-loss limits.

## Revision history

| version | date | change |
|---|---|---|
| v1 | 2026-09-22 | New clock-normalized research identity and three exact harness-v2 A-cell presets |
