# QM5_10511_mql5-n-candles - Strategy Spec

**EA ID:** QM5_10511
**Slug:** mql5-n-candles
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates the last completed H1 candles. It opens long when all of the last `N` completed candles closed above their opens, and opens short when all of the last `N` completed candles closed below their opens. New entries require no existing position for the current symbol and magic, optional session gating to allow trading, and the framework news gate to allow trading. Exits occur through the fixed ATR stop, fixed reward-to-risk target, framework Friday close, or an opposite `N`-candle streak.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_n_candles` | 3 | 1-20 | Number of completed candles that must all be bullish or bearish. |
| `strategy_atr_period` | 14 | 1-200 | ATR lookback used for the hard stop distance. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | ATR multiplier for the fixed hard stop. |
| `strategy_tp_rr` | 1.25 | 0.1-10.0 | Take-profit distance as a multiple of initial risk. |
| `strategy_session_enabled` | false | true/false | Enables the fixed broker-hour trading window. |
| `strategy_session_start_h` | 0 | 0-23 | Broker hour where the optional session window starts. |
| `strategy_session_end_h` | 24 | 0-24 | Broker hour where the optional session window ends. |
| `strategy_max_spread_points` | 0 | 0-10000 | Optional spread cap in points; 0 disables the cap. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major suitable for completed-bar OHLC streak logic.
- `GBPUSD.DWX` - liquid FX major suitable for completed-bar OHLC streak logic.
- `USDJPY.DWX` - liquid FX major suitable for completed-bar OHLC streak logic.
- `XAUUSD.DWX` - liquid metal symbol explicitly included by the approved card.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified DWX data path.

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
| Trades / year / symbol | 130 |
| Typical hold time | hours to days, bounded by opposite streak, SL, TP, or Friday close |
| Expected drawdown profile | trend-continuation streak system with losing clusters during choppy reversal regimes |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** Vladimir Karputov, "N-_Candles_v7", MQL5 CodeBase, published 2018-06-16, https://www.mql5.com/en/code/20500
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10511_mql5-n-candles.md`

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
| v1 | 2026-05-28 | Initial build from card | 9e4f693a-63a4-4ffe-ba96-d56a47dd2fa8 |
