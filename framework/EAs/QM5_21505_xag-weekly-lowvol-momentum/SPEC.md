# QM5_21505_xag-weekly-lowvol-momentum - Strategy Spec

**EA ID:** QM5_21505
**Slug:** `xag-weekly-lowvol-momentum`
**Source:** `ZHAO-ST-MOMREV-2026_XAG_S01`
**Author of this spec:** Gemini
**Last revised:** 2026-08-17

## 1. Strategy Logic

This EA implements a low-frequency silver momentum continuation sleeve on
`XAGUSD.DWX`. At the first D1 bar in each framework broker-week bucket, it
computes the latest completed five-D1 return and the tick-volume sum over the
same five bars. It ranks that sum against 40 earlier, non-overlapping five-bar
tick-volume windows. A rank in the bottom tercile (at or below 33%) permits a
trade in the same direction as the trailing five-bar return (continuation); a
higher volume rank or a zero return stays flat.

The weekly key is persisted before history, news, spread, quote, and order
gates, so a failed attempt cannot retry within the same week. An accepted
entry receives a frozen ATR hard stop and no take-profit. The position exits
after 10 completed D1 bars, upon a signal-flip re-evaluation, at the hard stop,
or through the framework Friday close. There is no trailing stop or scale-in.

Tick volume is an explicit runtime proxy for the source's unavailable
investor-position-derived speculative-flow component (representing the
residual non-flow portion). This sleeve forms a matched pair with `QM5_21504`
(high-volume fade on XNGUSD).

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_vol_lookback` | 40 | 26, 40, 60 | Earlier non-overlapping five-bar volume windows |
| `strategy_vol_percentile` | 33.0 | 20.0, 33.0, 40.0 | Maximum empirical tick-volume percentile (low-vol tercile) |
| `strategy_atr_period` | 14 | 10, 14, 20 | Completed-D1 ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.5 | 2.0, 2.5, 3.0, 3.5 | ATR hard-stop distance |
| `strategy_max_hold_bars` | 10 | 7, 10, 15 | Completed D1 bars before time exit |
| `strategy_max_spread_points` | 250 | 150, 250, 400 | Entry spread ceiling in points |

## 3. Symbol Universe

- `XAGUSD.DWX` only, magic slot 0, magic `215050000`.
- No external signal feed, secondary symbol, or basket leg is used.

## 4. Timeframe

- Host and signal timeframe: D1.
- Calendar gate: framework `PERIOD_W1` key evaluated on new D1 bars.
- All signal, volume, ATR, and time-exit inputs use completed D1 bars.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 15-18 as a research prior.
- Direction: symmetric long/short, following the latest five-D1 move during low-volume weeks.
- Typical hold: up to 10 completed D1 bars, with hard-stop and Friday-close authority.
- Q02 risk mode: `RISK_FIXED`.

## 6. Source Citation

Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. "Momentum and Reversal on
the Short-Term Horizon: Evidence from Commodity Markets." SSRN, 2026,
https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | `RISK_FIXED` | 1000 |
| Backtest percentage risk | `RISK_PERCENT` | 0 |
| Backtest portfolio weight | `PORTFOLIO_WEIGHT` | 1 |
| Live, if ever approved later | `RISK_PERCENT` | allocated by portfolio process |

The EA holds at most one position per magic and symbol, uses the V5 framework
risk sizing and kill switch, applies a frozen `2.5 * ATR(14,D1)` hard stop,
and fails closed on invalid history, volume, ATR, spread, quote, or stop data.
