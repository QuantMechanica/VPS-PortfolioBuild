# QM5_20205_wti-calmom1 - Strategy Spec

**EA ID:** QM5_20205

**Slug:** `wti-calmom1`

**Strategy ID:** `KELOHARJU-MOP-WTI-CALMOM1-2026_S01`

**Source:** `KELOHARJU-MOP-WTI-CALMOM1-2026`

**Last revised:** 2026-08-03

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of each broker month, reconstruct
WTI's average return for that same calendar month over the prior ten years,
requiring at least five valid observations. Independently reconstruct WTI's
exact immediately completed broker-calendar-month log return.

Open one long WTI position when both states are strictly positive and one
short position when both are strictly negative. Disagreement, exact zero, or
invalid history consumes the month and remains flat. Close at the next month
boundary or after 35 calendar days. Every entry carries a frozen
`3.5 * ATR(20,D1)` hard stop and no take-profit.

The exact one-month agreement state is load-bearing. `QM5_20137_wti-seas-pb`
trades only the disjoint sign-disagreement state, while `QM5_20136_wti-caltrend`
uses a 63-D1 trend instead of exact completed month endpoints.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_history_years` | 10 | locked | Prior same-calendar years inspected |
| `strategy_min_history_years` | 5 | locked | Minimum valid seasonal samples |
| `strategy_history_bars` | 3000 | locked | Bounded D1 reconstruction buffer |
| `strategy_min_abs_return_pct` | 0.0 | locked | Strict sign; no fitted deadband |
| `strategy_atr_period` | 20 | locked | Completed D1 hard-stop estimator |
| `strategy_atr_sl_mult` | 3.5 | locked | Frozen stop multiple |
| `strategy_max_hold_days` | 35 | locked | Stale monthly-package guard |
| `strategy_max_spread_points` | 1500 | locked | WTI entry spread ceiling |

There is no Q02 parameter sweep.

## 3. Symbol Universe

- `XTIUSD.DWX`: host and traded symbol, magic slot 0, magic `202050000`.
- No second symbol, external feed, or carrier substitution is authorized.

## 4. Timeframe

- Base timeframe: D1.
- Decision cadence: first genuine D1 bar of each broker-calendar month.
- Formation: completed month-end closes only; current-month prices never enter
  either signal.
- Holding period: next month boundary, maximum 35 calendar days.

## 5. Expected Behaviour

- Approximately 5-8 packages/year after the five-year warm-up; Q02 retires
  below five completed trades/year.
- Symmetric long/short directional WTI exposure.
- High risk from oil gaps, financing, continuous-CFD basis, one-name breadth,
  and sparse agreement.
- Direct WTI is a new economic carrier for the certified XAU/SP500/NDX/XNG
  book, but realized decorrelation is not claimed.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities,"
*The Journal of Finance* 71(4), 1557-1590,
DOI `10.1111/jofi.12398`, supplies the same-calendar commodity state.

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum,"
*Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`, supplies the one-month own-return
continuation state.

The complete evidence and translation boundary is
`strategy-seeds/sources/KELOHARJU-MOP-WTI-CALMOM1-2026/source.md`; the approved
card is `strategy-seeds/cards/approved/QM5_20205_wti-calmom1_card.md`.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Fixed risk is normalized through the frozen hard stop.
Friday close and both news axes are disabled for the month-spanning native
price baseline. Broker hard stop, framework kill switch, month-boundary exit,
stale close, deal-history guard, and persisted attempt state remain active.

No live/demo/shadow setfile, take-profit, trail, partial close, grid,
martingale, scale-in, pyramid, external runtime call, AutoTrading action,
`T_Live` artifact, deploy manifest, portfolio admission, or gate change is
authorized.

## 8. Framework Alignment

- No-trade: exact host/timeframe/ID/slot, locked input, month, history,
  arithmetic, spread, quote, ATR, attempt, and framework safety gates.
- Trade entry: historical same-calendar and exact completed-month agreement,
  registered magic, framework fixed-risk sizing, and frozen hard stop.
- Trade management: next-month close and 35-day stale close before entry-only
  gates.
- Trade close: framework close helper, broker hard stop, and kill switch.
