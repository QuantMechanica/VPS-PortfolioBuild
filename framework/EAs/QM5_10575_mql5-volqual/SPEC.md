# QM5_10575_mql5-volqual - Strategy Spec

**EA ID:** QM5_10575
**Slug:** mql5-volqual
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades the closed-bar color changes of the VolatilityQuality line. It enters long when the latest closed H4 VolatilityQuality state changes from bearish to bullish, and enters short when it changes from bullish to bearish. Open long positions close on a bearish color change, and open short positions close on a bullish color change. Each entry uses an ATR(14) hard stop at 2.0 ATR and a 1.5R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_vq_length | 5 | >=1 | VolatilityQuality moving-average length from the source indicator default. |
| strategy_vq_smoothing | 1 | >=1 | Closed-bar lag used for the VolatilityQuality smoothed-price comparison. |
| strategy_vq_filter_points | 5 | >=0 | Source-style minimum line-delta filter in symbol points. |
| strategy_vq_ma_method | MODE_LWMA | MODE_SMA, MODE_EMA, MODE_SMMA, MODE_LWMA | Moving average method used for VolatilityQuality smoothing. |
| strategy_vq_price | PRICE_MEDIAN | MQL5 applied price enum | Applied price used for the main VolatilityQuality price series. |
| strategy_atr_period | 14 | >=1 | ATR period for the P2 baseline hard stop. |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiple for the hard stop. |
| strategy_rr_target | 1.5 | >0 | Reward/risk target multiple. |

---

## 3. Symbol Universe

**Designed for:**
- GBPJPY.DWX - card primary and source-test style H4 FX volatility pair.
- EURUSD.DWX - portable liquid DWX FX major for the R3 P2 basket.
- GBPUSD.DWX - portable liquid DWX FX major for the R3 P2 basket.
- XAUUSD.DWX - portable liquid DWX metal for the R3 P2 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol data target exists for build registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | multi-bar H4 holds, usually hours to days |
| Expected drawdown profile | trend color-change strategy with losses bounded by ATR stop and 1.5R target |
| Regime preference | volatility-quality trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/14312
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10575_mql5-volqual.md`

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
| v1 | 2026-06-11 | Initial build from card | 22323571-2a95-4b14-8da2-d4c2c1d5ccc0 |
