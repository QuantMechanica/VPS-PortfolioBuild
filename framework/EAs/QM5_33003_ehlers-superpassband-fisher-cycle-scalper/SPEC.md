# QM5_33003_ehlers-superpassband-fisher-cycle-scalper — Strategy Spec

**EA ID:** QM5_33003
**Slug:** ehlers-superpassband-fisher-cycle-scalper
**Source:** ehlers-superpassband-fisher-cycle-scalper-official-source
**Author of this spec:** Gemini
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

The strategy implements John Ehlers' Digital Signal Processing (DSP) model combining a 2nd-order SuperPassBand filter with the Fisher Transform to isolate cyclical turning points with minimal lag on H1 forex pairs (EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX).

A HighPass filter strips DC trend components, while the SuperPassBand filter isolates dominant cyclical frequencies. The Fisher Transform maps the normalized cyclic output into a Gaussian probability distribution.

A LONG entry is triggered on a closed H1 bar when the Fisher indicator turns up from below its 1-bar trigger line in deep oversold territory (Fisher[1] <= -1.50). A SHORT entry is triggered when the Fisher indicator turns down from above its 1-bar trigger line in deep overbought territory (Fisher[1] >= +1.50). Positions are managed with an initial 1.5x ATR hard stop loss, a 3.0x ATR take profit (1:2.0 R:R), and a cycle exit when the Fisher line crosses zero.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_period` | 10 | 5-15 | SuperPassBand high cutoff frequency / Fisher normalization window |
| `strategy_slow_period` | 40 | 25-60 | SuperPassBand low cutoff frequency / HighPass period |
| `strategy_fisher_threshold` | 1.50 | 1.0-2.5 | Fisher Transform extreme turning point threshold |
| `strategy_atr_period` | 14 | 10-20 | ATR period for volatility-based SL/TP and spread filters |
| `strategy_atr_sl_mult` | 1.5 | 1.0-2.5 | ATR multiplier for stop loss distance |
| `strategy_atr_tp_mult` | 3.0 | 2.0-5.0 | ATR multiplier for take profit distance |
| `strategy_spread_atr_mult` | 1.8 | 1.2-2.5 | Maximum allowable spread relative to ATR |
| `strategy_warmup_bars` | 120 | 80-200 | Historical bar window for recursive DSP filter stabilization |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` (Primary, slot 0) — High liquidity major FX pair with persistent cycle characteristics.
- `GBPUSD.DWX` (slot 1) — High liquidity major FX pair.
- `USDJPY.DWX` (slot 2) — High liquidity major FX pair.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | 8 to 36 hours |
| Expected drawdown profile | <= 15% peak-to-trough equity drawdown |
| Regime preference | Mean-reverting cycle swings / oscillator extremes |
| Win rate target (qualitative) | High (60% to 75% with positive payoff ratio) |

---

## 6. Source Citation

**Source ID:** `ehlers-superpassband-fisher-cycle-scalper-official-source`
**Source type:** Academic / Quantitative Book
**Pointer:** Ehlers, J. F. (2013). Cycle Analytics for Traders. John Wiley & Sons.
**R1–R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/approved/QM5_33003_ehlers-superpassband-fisher-cycle-scalper.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | Initial build from approved card | Router task 835cea6d-11ab-4330-ad7d-c5117b37cb31 |
