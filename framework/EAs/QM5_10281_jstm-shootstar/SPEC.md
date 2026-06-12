# QM5_10281_jstm-shootstar - Strategy Spec

**EA ID:** QM5_10281
**Slug:** `jstm-shootstar`
**Source:** `1b906e79-c619-5a61-90db-ee19ac95a19f` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

This EA trades short on D1 after a bearish shooting-star candle is confirmed by the next daily bar. The setup requires a two-bar uptrend into the shooting star, a bearish body, a small lower wick, a long upper wick, and a body smaller than the recent average body. The EA enters short after the confirmation bar closes, then exits when price moves 5% from entry in either direction or when the position has been open for 7 D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_body_avg_lookback` | 20 | 1+ | Number of prior D1 bars used for the signed mean body threshold. |
| `strategy_lower_wick_body_max` | 0.20 | 0.0+ | Maximum lower-wick-to-body ratio for the shooting-star candle. |
| `strategy_body_mean_mult` | 0.50 | >0.0 | Maximum body size as a multiple of the recent mean body. |
| `strategy_upper_wick_body_min` | 2.00 | >0.0 | Minimum upper-wick-to-body ratio for the shooting-star candle. |
| `strategy_exit_move_pct` | 5.00 | >0.0 | Absolute percentage move from entry that closes the trade. |
| `strategy_max_hold_d1_bars` | 7 | 1+ | Maximum holding period in D1 trading bars. |

---

## 3. Symbol Universe

**Designed for:**
- `AUDCAD.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `AUDCHF.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `AUDJPY.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `AUDNZD.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `AUDUSD.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `CADCHF.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `CADJPY.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `CHFJPY.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `EURAUD.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `EURCAD.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `EURCHF.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `EURGBP.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `EURJPY.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `EURNZD.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `EURUSD.DWX` - liquid FX pair with daily OHLC available in the matrix.
- `GBPAUD.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `GBPCAD.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `GBPCHF.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `GBPJPY.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `GBPNZD.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `GBPUSD.DWX` - liquid FX pair with daily OHLC available in the matrix.
- `GDAXI.DWX` - index CFD with daily OHLC available in the matrix.
- `NDX.DWX` - index CFD with daily OHLC available in the matrix.
- `NZDCAD.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `NZDCHF.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `NZDJPY.DWX` - liquid FX cross with daily OHLC available in the matrix.
- `NZDUSD.DWX` - liquid FX pair with daily OHLC available in the matrix.
- `SP500.DWX` - S&P 500 custom symbol with daily OHLC available for backtest.
- `UK100.DWX` - index CFD with daily OHLC available in the matrix.
- `USDCAD.DWX` - liquid FX pair with daily OHLC available in the matrix.
- `USDCHF.DWX` - liquid FX pair with daily OHLC available in the matrix.
- `USDJPY.DWX` - liquid FX pair with daily OHLC available in the matrix.
- `WS30.DWX` - index CFD with daily OHLC available in the matrix.
- `XAGUSD.DWX` - metal symbol with daily OHLC available in the matrix.
- `XAUUSD.DWX` - metal symbol with daily OHLC available in the matrix.

**Explicitly NOT for:**
- `XTIUSD.DWX` - energy commodity, not part of the card's index, metal, and FX target set.
- `XNGUSD.DWX` - energy commodity, not part of the card's index, metal, and FX target set.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | 1-7 trading days |
| Expected drawdown profile | Short-reversal losses cluster when uptrends continue after failed shooting-star signals. |
| Regime preference | reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1b906e79-c619-5a61-90db-ee19ac95a19f`
**Source type:** GitHub source file
**Pointer:** `https://github.com/je-suis-tm/quant-trading/blob/master/Shooting%20Star%20backtest.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10281_jstm-shootstar.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-12 | Initial build from card | 1bad5002-5c11-4f10-b057-5056a80016d8 |
