# QM5_10551_mql5-macd-atr — Strategy Spec

**EA ID:** QM5_10551
**Slug:** mql5-macd-atr
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA measures MACD main minus MACD signal on closed H1 bars and compares that delta with an ATR-scaled threshold. It opens long when the closed-bar delta crosses upward through `ATR(14) * LEVEL`, and opens short when it crosses downward through `-ATR(14) * LEVEL`. Long positions close when the delta crosses back below zero; short positions close when the delta crosses back above zero. Each trade also has an ATR(14) 2.0 hard stop and a 1.5R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | H1/H4 sweep intended by card | Timeframe used for MACD and ATR signal reads. |
| `strategy_macd_fast` | 9 | 1 to below slow period | MACD fast EMA period. |
| `strategy_macd_slow` | 15 | above fast period | MACD slow EMA period. |
| `strategy_macd_signal` | 8 | 1 or higher | MACD signal smoothing period. |
| `strategy_level` | 0.004 | above 0 | Multiplier applied to ATR for the MACD delta threshold. |
| `strategy_atr_period` | 14 | 1 or higher | ATR period used for threshold and hard stop. |
| `strategy_atr_sl_mult` | 2.0 | above 0 | ATR multiple used for the stop loss. |
| `strategy_target_r_multiple` | 1.5 | above 0 | Take-profit distance in multiples of initial stop risk. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary liquid FX major from the card's R3 P2 basket.
- `GBPUSD.DWX` — liquid FX major from the card's R3 P2 basket.
- `USDJPY.DWX` — liquid FX major from the card's R3 P2 basket.
- `XAUUSD.DWX` — liquid metal symbol from the card's R3 P2 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — unavailable in the DWX test universe.

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
| Trades / year / symbol | 50 |
| Typical hold time | Intraday to multi-day depending on MACD zero-cross or ATR bracket hit. |
| Expected drawdown profile | Fixed-risk trend trigger with losses bounded by the ATR hard stop. |
| Regime preference | Moderate intraday trend and volatility expansion. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/17080
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10551_mql5-macd-atr.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-29 | Initial build from card | 8fd07fb4-8034-40d6-a316-a49815fd4efc |
