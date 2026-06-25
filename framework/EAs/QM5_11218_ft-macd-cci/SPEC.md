# QM5_11218_ft-macd-cci - Strategy Spec

**EA ID:** QM5_11218
**Slug:** ft-macd-cci
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades long on M5 closed bars when the MACD main line is above the MACD signal line and CCI is at or below the fixed buy threshold. It opens at the next bar's market price with an ATR(14) stop at 1.5x ATR. It exits when the source ROI ladder is reached, when the disaster loss cap is reached, or when MACD is below signal and CCI is at or above the sell threshold. News, Friday close, risk, and one-position-per-magic behavior are handled by the V5 framework.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_macd_fast` | 12 | 8-16 | MACD fast EMA period from the card sweep. |
| `strategy_macd_slow` | 26 | 21-34 | MACD slow EMA period from the card sweep. |
| `strategy_macd_signal` | 9 | fixed | MACD signal period. |
| `strategy_cci_period` | 14 | fixed | CCI period using typical price. |
| `strategy_buy_cci` | -48.0 | -100 to -25 | Long entry CCI threshold. |
| `strategy_sell_cci` | 687.0 | 100 to 687 | Signal-exit CCI threshold. |
| `strategy_atr_period` | 14 | fixed | ATR period for the protective stop. |
| `strategy_sl_atr_mult` | 1.5 | 1.0-2.0 | ATR stop-loss multiplier. |
| `strategy_spread_pct_of_stop` | 6.0 | fixed | Blocks only spread wider than this percent of planned stop distance. |
| `strategy_roi_0_min_pct` | 5.0 | fixed | ROI exit threshold before 20 minutes. |
| `strategy_roi_20_min_pct` | 4.0 | fixed | ROI exit threshold after 20 minutes. |
| `strategy_roi_30_min_pct` | 3.0 | fixed | ROI exit threshold after 30 minutes. |
| `strategy_roi_60_min_pct` | 1.0 | fixed | ROI exit threshold after 60 minutes. |
| `strategy_disaster_loss_pct` | 30.0 | fixed | Source stoploss disaster cap; ATR stop is the MT5 baseline stop. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - DWX forex major with OHLC data for MACD and CCI.
- `GBPUSD.DWX` - DWX forex major with OHLC data for MACD and CCI.
- `USDJPY.DWX` - DWX forex major with OHLC data for MACD and CCI.
- `XAUUSD.DWX` - DWX metal symbol with OHLC data for MACD and CCI.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest artifacts must use the registered `.DWX` symbols.
- Symbols outside `dwx_symbol_matrix.csv` - no broker/custom-symbol data guarantee.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | minutes to hours, governed by M5 signal exit and ROI ladder |
| Expected drawdown profile | medium risk from frequent M5 entries with ATR stop protection |
| Regime preference | MACD trend state with CCI pullback filter |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy source
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/MACDStrategy.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11218_ft-macd-cci.md`

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
| v1 | 2026-06-25 | Initial build from card | 035e373c-fc36-4514-9735-36e29895c964 |
