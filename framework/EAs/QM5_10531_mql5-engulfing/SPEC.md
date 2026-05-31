# QM5_10531_mql5-engulfing - Strategy Spec

**EA ID:** QM5_10531
**Slug:** mql5-engulfing
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA trades two-candle bullish and bearish engulfing reversals on closed H1 bars. A long signal requires the previous candle to be bearish, the latest closed candle to be bullish, and the latest real body to engulf the previous real body; a short signal mirrors those rules. The latest engulfing body must be at least 0.5 ATR(14), with optional SMA(50) trend filtering disabled by default. Positions exit at the hard stop, at 1.5R take-profit, after 8 H1 bars, or when an opposite engulfing pattern appears.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 5-50 | ATR period used for body-size and volatility stop calculations. |
| `strategy_min_body_atr_mult` | 0.50 | 0.30-0.80 | Minimum latest candle real body as a multiple of ATR. |
| `strategy_atr_sl_mult` | 1.00 | 1.00-1.20 | ATR stop multiple; stop uses the farther of ATR stop and pattern extreme. |
| `strategy_tp_rr` | 1.50 | 1.00-2.00 | Take-profit as reward-to-risk multiple. |
| `strategy_time_stop_bars` | 8 | 6-12 | Maximum H1 bars to hold before strategy close. |
| `strategy_use_sma50_filter` | false | true/false | Optional trend filter from the card sweep notes. |
| `strategy_sma_period` | 50 | 20-200 | SMA period used when the optional trend filter is enabled. |
| `strategy_max_spread_points` | 0 | 0+ | Optional strategy spread cap; 0 defers to framework defaults. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed DWX major FX symbol with H1 OHLC and ATR coverage.
- `GBPUSD.DWX` - card-listed DWX major FX symbol with H1 OHLC and ATR coverage.
- `USDJPY.DWX` - card-listed DWX major FX symbol with H1 OHLC and ATR coverage.
- `XAUUSD.DWX` - card-listed DWX metals symbol with H1 OHLC and ATR coverage.

**Explicitly NOT for:**
- Non-DWX symbols - build and P2 routing require canonical `.DWX` symbols registered in `dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Up to 8 H1 bars |
| Expected drawdown profile | Reversal-pattern losses cluster during persistent one-way trends. |
| Regime preference | Candlestick reversal after short-term directional movement |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/18487
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10531_mql5-engulfing.md`

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
| v1 | 2026-05-29 | Initial build from card | ac624fbb-82c7-404c-907e-98b6701e1e44 |
