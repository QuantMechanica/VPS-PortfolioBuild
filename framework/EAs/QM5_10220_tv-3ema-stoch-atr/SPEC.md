# QM5_10220_tv-3ema-stoch-atr - Strategy Spec

**EA ID:** QM5_10220
**Slug:** tv-3ema-stoch-atr
**Source:** 30591366-874b-5bee-b47c-da2fca20b728 (see `sources/tradingview-popular-pine-scripts`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades in the direction of an 8/20/40 EMA stack on the current chart timeframe. A long entry is opened when EMA8 is above EMA20 and EMA20 is above EMA40, and a bounded StochRSI confirmation line crosses above its signal line on the last closed bar. A short entry mirrors the rule when EMA8 is below EMA20 and EMA20 is below EMA40, with the StochRSI confirmation line crossing below its signal line. Every entry uses a fixed ATR bracket: stop loss at 3.0 ATR from entry and take profit at 2.0 ATR from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast` | 8 | integer > 0 | Fast EMA period for the trend stack. |
| `strategy_ema_mid` | 20 | integer > 0 | Middle EMA period for the trend stack. |
| `strategy_ema_slow` | 40 | integer > 0 | Slow EMA period for the trend stack. |
| `strategy_rsi_period` | 14 | integer > 0 | RSI period used as the input series for StochRSI. |
| `strategy_stoch_period` | 14 | integer > 1 | Lookback window for min/max RSI normalization. |
| `strategy_stoch_k_smooth` | 3 | integer > 0 | Smoothing length for the StochRSI confirmation line. |
| `strategy_stoch_d_smooth` | 3 | integer > 0 | Smoothing length for the StochRSI signal line. |
| `strategy_atr_period` | 14 | integer > 0 | ATR period for the fixed bracket. |
| `strategy_atr_tp_mult` | 2.0 | double > 0 | Take-profit distance in ATR multiples. |
| `strategy_atr_sl_mult` | 3.0 | double > 0 | Stop-loss distance in ATR multiples. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid DWX forex major with native OHLC data for EMA, RSI, and ATR.
- `GBPUSD.DWX` - liquid DWX forex major with the same indicator data requirements.
- `XAUUSD.DWX` - DWX gold CFD; trend and ATR bracket logic are portable to metals.
- `GDAXI.DWX` - canonical DWX DAX custom symbol, used as the matrix-available port for the card's `GER40.DWX` target.
- `NDX.DWX` - DWX Nasdaq 100 index CFD; trend/momentum/ATR logic is portable to this index.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` primary; `M30` also generated because the card names both for first tests |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 140 |
| Typical hold time | intraday to multi-day, bounded by fixed ATR SL/TP and Friday close |
| Expected drawdown profile | trend-following drawdown during range-bound whipsaw periods |
| Regime preference | trend with momentum confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView public script
**Pointer:** TradingView script `3 x EMA + Stochastic RSI + ATR`, author handle `tomimarson`, published 2021-06-11, https://www.tradingview.com/script/NOFMegun-3-x-EMA-Stochastic-RSI-ATR/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10220_tv-3ema-stoch-atr.md`

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
| v1 | 2026-06-09 | Initial build from card | 98b43ee1-61c5-4ffe-a605-295987656f81 |
