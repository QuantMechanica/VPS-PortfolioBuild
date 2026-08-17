# QM5_21502_xau-weekly-tsmom - Strategy Spec

**EA ID:** QM5_21502
**Slug:** `xau-weekly-tsmom`
**Source:** `ZHAO-ST-MOMREV-2026_XAU_S01`
**Author of this spec:** Gemini
**Last revised:** 2026-08-17

## 1. Strategy Logic

This EA implements a low-frequency gold weekly time-series momentum sleeve on
`XAUUSD.DWX`. At the first D1 bar in each framework broker-week bucket, it
computes the trailing 5-bar completed D1 return: `(Close[1] - Close[6]) / Close[6]`.
If return is positive, it signals BUY (+1); if return is negative, it signals SELL (-1).
If a position is currently open in the same direction as the signal, it holds.
If a position is open in the opposite direction, it closes the existing position
and opens the new position (signal-flip exit).

The weekly key is persisted before history, news, spread, quote, and order
gates, so a failed attempt cannot retry within the same week. An accepted
entry receives a frozen ATR hard stop and no take-profit. The position exits
after 15 completed D1 bars (3 weekly cycles), upon a signal-flip, at the hard stop,
or through the framework Friday close. There is no trailing stop, partial close,
or scale-in.

This is a disclosed mechanical price-only proxy of the paper's short-horizon
commodity momentum finding, using native D1 OHLC with no external position/COT data.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_lookback_bars` | 5 | 3, 5, 8, 10 | Completed D1 bars for weekly return calculation |
| `strategy_atr_period` | 14 | 10, 14, 20 | Completed-D1 ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.5 | 2.0, 2.5, 3.0, 3.5 | ATR hard-stop distance |
| `strategy_max_hold_bars` | 15 | 10, 15, 21 | Completed D1 bars before max-hold time exit |
| `strategy_max_spread_points` | 300 | 150, 300, 500 | Entry spread ceiling in points |

## 3. Symbol Universe

- `XAUUSD.DWX` only, magic slot 0, magic `215020000`.
- No external signal feed, secondary symbol, or basket leg is used.

## 4. Timeframe

- Host and signal timeframe: D1.
- Calendar gate: framework `PERIOD_W1` key evaluated on new D1 bars.
- All signal, ATR, and time-exit inputs use completed D1 bars.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 25-35 as a research prior.
- Direction: symmetric long/short, following the latest weekly return sign.
- Typical hold: multi-day to 3 weeks (up to 15 completed D1 bars), with hard-stop and Friday-close authority.
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
and fails closed on invalid history, ATR, spread, quote, or stop data.
