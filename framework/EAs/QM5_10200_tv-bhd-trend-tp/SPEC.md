# QM5_10200_tv-bhd-trend-tp - Strategy Spec

**EA ID:** QM5_10200
**Slug:** `tv-bhd-trend-tp`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (TradingView script `Take Profit On Trend (by BHD_Trade_Bot)`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades long only on H1 bars. It enters when EMA(200) is rising, RSI(200) is above 51, and the two most recent completed candles are bearish. The order is a market buy on the next bar with TP at 1.0 * ATR(14) above entry and SL at 2.0 * ATR(14) below entry. Trades are skipped when spread is greater than 15% of the stop distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | M1-MN1 | Timeframe used for the EMA, RSI, ATR, and candle pullback checks. |
| `strategy_ema_period` | `200` | 2+ | Long-term trend EMA period. |
| `strategy_rsi_period` | `200` | 2+ | Long-term RSI regime period. |
| `strategy_rsi_min` | `51.0` | 0-100 | Minimum RSI value required for long entries. |
| `strategy_atr_period` | `14` | 1+ | ATR period used to size the bracket. |
| `strategy_atr_tp_mult` | `1.0` | 0+ | Take-profit distance in ATR multiples. |
| `strategy_atr_sl_mult` | `2.0` | 0+ | Stop-loss distance in ATR multiples. |
| `strategy_max_spread_stop_fraction` | `0.15` | 0-1 | Maximum spread as a fraction of stop distance. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair from the approved card target basket.
- `GBPUSD.DWX` - liquid major FX pair from the approved card target basket.
- `XAUUSD.DWX` - liquid gold CFD from the approved card target basket.
- `NDX.DWX` - liquid Nasdaq 100 index CFD from the approved card target basket.
- `GDAXI.DWX` - canonical DWX DAX symbol; used as the matrix-verified port of the card's `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- Any symbol not registered for this EA in `magic_numbers.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none by default; all strategy reads use `strategy_signal_tf` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Expected trade frequency | H1 pullback entries; card does not specify a finer cadence. |
| Typical hold time | ATR bracket hold; card does not specify duration. |
| Expected drawdown profile | Fixed-risk bracket losses, 2.0 * ATR stop distance. |
| Regime preference | Trend-following pullback in rising EMA/RSI regimes. |
| Win rate target (qualitative) | Medium; card does not specify a numeric target. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** `https://www.tradingview.com/script/iqtkNFT2-Take-Profit-On-Trend-by-BHD-Trade-Bot/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10200_tv-bhd-trend-tp.md`

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
| v1 | 2026-06-09 | Initial build from card | 5b9fe579-8623-4899-b373-563f19dd98ae |
