# QM5_10475_mql5-puria - Strategy Spec

**EA ID:** QM5_10475
**Slug:** `mql5-puria`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades the Puria MA/MACD setup on closed M30 bars. It enters long when the fast EMA(19, open) is more than 0.5 points below both slow SMMA(69, high) and SMMA(74, high), with MACD(17,38,1, open) positive and rising over the confirmation window. It enters short when the fast EMA is more than 0.5 points above both slow averages, with MACD negative and falling. Positions close on the opposite full setup, or through the ATR stop, 2R target, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ma_period` | 19 | 1-500 | Fast EMA period on open price. |
| `strategy_slow_ma_1_period` | 69 | 1-500 | First slow SMMA period on high price. |
| `strategy_slow_ma_2_period` | 74 | 1-500 | Second slow SMMA period on high price. |
| `strategy_ma_gap_points` | 0.5 | 0.0-100.0 | Minimum fast-vs-slow displacement in symbol points. |
| `strategy_macd_fast` | 17 | 1-100 | Fast EMA period for MACD confirmation. |
| `strategy_macd_slow` | 38 | 2-200 | Slow EMA period for MACD confirmation. |
| `strategy_macd_signal` | 1 | 1-50 | MACD signal smoothing period from the source implementation. |
| `strategy_macd_trend_bars` | 8 | 3-50 | Number of closed bars used to require MACD rising or falling. |
| `strategy_atr_period` | 14 | 1-100 | ATR period used for the initial stop. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | ATR multiple for initial stop distance. |
| `strategy_tp_r_multiple` | 2.0 | 0.1-10.0 | Take-profit distance as a multiple of initial risk. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only strategy-specific inputs are listed.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary source-test FX major from the card.
- `GBPUSD.DWX` - liquid DWX FX major suitable for MA/MACD testing.
- `USDJPY.DWX` - liquid DWX FX major suitable for MA/MACD testing.
- `USDCHF.DWX` - liquid DWX FX major suitable for MA/MACD testing.
- `USDCAD.DWX` - liquid DWX FX major suitable for MA/MACD testing.
- `AUDUSD.DWX` - liquid DWX FX major suitable for MA/MACD testing.
- `NZDUSD.DWX` - liquid DWX FX major suitable for MA/MACD testing.

**Explicitly NOT for:**
- `SP500.DWX` - card is FX-major scoped, not index scoped.
- `XAUUSD.DWX` - card is FX-major scoped, not metal scoped.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | `intraday to multi-day, bounded by opposite setup / ATR stop / 2R target` |
| Expected drawdown profile | `moderate trend-following/contrarian MA whipsaw risk during choppy FX regimes` |
| Regime preference | `trend-following with MACD-confirmed MA displacement` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/23250`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10475_mql5-puria.md`

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
| v1 | 2026-05-28 | Initial build from card | 5fdae4a8-6b45-49ab-86df-85554846d358 |
