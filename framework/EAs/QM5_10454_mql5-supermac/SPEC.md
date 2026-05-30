# QM5_10454_mql5-supermac - Strategy Spec

**EA ID:** QM5_10454
**Slug:** mql5-supermac
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades a moving-average crossover only when MACD confirms the same direction. A long entry is allowed when the fast moving average crosses above the slow moving average on the last closed bar and the MACD main line is above its signal line with positive histogram. A short entry is the mirrored condition. Positions use an ATR-based initial stop, a fixed reward-to-risk take-profit, and close early only when the opposite MA crossover and MACD confirmation are both present.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ma_period` | 20 | 1-200 | Fast moving-average period. |
| `strategy_slow_ma_period` | 50 | 2-400 | Slow moving-average period; must be greater than the fast period. |
| `strategy_ma_method` | `MODE_SMA` | `MODE_SMA`, `MODE_EMA`, `MODE_SMMA`, `MODE_LWMA` | Moving-average method used for crossover detection. |
| `strategy_ma_price` | `PRICE_CLOSE` | MT5 applied-price enum | Applied price used by MA and MACD readers. |
| `strategy_macd_fast` | 12 | 1-100 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | 2-200 | MACD slow EMA period; must be greater than MACD fast. |
| `strategy_macd_signal` | 9 | 1-100 | MACD signal period. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for initial stop distance. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | ATR multiplier for initial stop distance. |
| `strategy_tp_rr` | 2.0 | 0.1-10.0 | Fixed take-profit as reward-to-risk multiple of initial stop. |
| `strategy_min_bars` | 80 | 50-1000 | Minimum loaded bars before the EA can trade. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid DWX FX major suitable for H1 MA/MACD trend signals.
- `GBPUSD.DWX` - liquid DWX FX major suitable for H1 MA/MACD trend signals.
- `USDJPY.DWX` - liquid DWX FX major suitable for H1 MA/MACD trend signals.
- `USDCHF.DWX` - liquid DWX FX major suitable for H1 MA/MACD trend signals.
- `USDCAD.DWX` - liquid DWX FX major suitable for H1 MA/MACD trend signals.
- `AUDUSD.DWX` - liquid DWX FX major suitable for H1 MA/MACD trend signals.
- `NZDUSD.DWX` - liquid DWX FX major suitable for H1 MA/MACD trend signals.
- `XAUUSD.DWX` - card explicitly includes gold in the liquid baseline basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtests.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | hours to days |
| Expected drawdown profile | trend-following drawdowns during ranging or whipsaw regimes |
| Regime preference | trend / momentum-confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** MQL5 CodeBase, "SUPERMACBOT - expert for MetaTrader 5", author Simon Githiri Kamau, published 2024-11-15, https://www.mql5.com/en/code/53526
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10454_mql5-supermac.md`

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
| v1 | 2026-05-28 | Initial build from card | e00d4139-a9a1-4e25-b0d4-c44a68113d33 |
