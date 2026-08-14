# QM5_21504_xng-flowrev - Strategy Spec

**EA ID:** QM5_21504
**Slug:** `xng-flowrev`
**Source:** `ZHAO-ST-MOMREV-2026_XNG_S03`
**Author of this spec:** Codex
**Last revised:** 2026-08-14

## 1. Strategy Logic

This EA implements a low-frequency natural-gas reversal sleeve on
`XNGUSD.DWX`. At the first D1 bar in each framework broker-week bucket, it
computes the latest completed five-D1 return and the tick-volume sum over the
same five bars. It ranks that sum against 40 earlier, non-overlapping five-bar
tick-volume windows. A rank at or above 75% permits a trade opposite the return
sign; a lower rank or a zero return stays flat.

The weekly key is persisted before history, news, spread, quote, and order
gates, so a failed attempt cannot retry within the same week. An accepted
entry receives a frozen ATR hard stop and no take-profit. The position exits
after five completed D1 bars, at the hard stop, or through the framework Friday
close. There is no opposite-signal exit, trailing stop, or scale-in.

Tick volume is an explicit runtime proxy for the source's unavailable
investor-position-derived speculative-flow component. This sleeve is distinct
from `QM5_12567` (long-only cumulative-RSI pullback) and `QM5_13102` (minimum
return shock plus realized-volatility rank and neutral-band exit).

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_vol_lookback` | 40 | 26, 40, 60 | Earlier non-overlapping five-bar volume windows |
| `strategy_vol_percentile` | 75.0 | 67, 75, 85 | Minimum empirical tick-volume percentile |
| `strategy_atr_period` | 14 | 10, 14, 20 | Completed-D1 ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.5 | 2.0, 2.5, 3.0, 3.5 | ATR hard-stop distance |
| `strategy_max_hold_bars` | 5 | 3, 5, 7 | Completed D1 bars before time exit |
| `strategy_max_spread_points` | 600 | 300, 600, 1000 | Entry spread ceiling in points |

The five-bar return/volume window, non-overlapping baseline construction,
tick-volume input, symmetric fade direction, and one-attempt-per-week rule are
locked.

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0, magic `215040000`.
- No external signal feed, secondary symbol, or basket leg is used.

## 4. Timeframe

- Host and signal timeframe: D1.
- Calendar gate: framework `PERIOD_W1` key evaluated on new D1 bars.
- All signal, volume, ATR, and time-exit inputs use completed D1 bars.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 10-14 as a research prior, not test
  evidence; Q02 must reject below five completed trades per full post-warm-up
  year.
- Direction: symmetric long/short, opposite the latest five-D1 move.
- Regime: unusually high native tick-volume weeks in natural gas.
- Typical hold: up to five completed D1 bars, with hard-stop and Friday-close
  authority.
- Q02 risk mode: `RISK_FIXED`.

## 6. Source Citation

Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. "Momentum and Reversal on
the Short-Term Horizon: Evidence from Commodity Markets." SSRN, 2026, DOI
10.2139/ssrn.6425598,
https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598.

The governed source packet contains metadata and accessible abstract and
methodology summaries, not inaccessible full text. The paper supplies the
weekly reversal direction for a speculative-flow component; it does not supply
the tick-volume proxy, XNG carrier, stop, or execution limits used here.

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

This build is non-live. It creates no live/demo/shadow/stress setfile and has
no deploy, portfolio-admission, `T_Live`, or AutoTrading authority.
