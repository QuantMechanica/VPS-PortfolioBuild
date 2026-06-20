# QM5_11419_144-lwma-5smma-proximity-crossover-m5 - Strategy Spec

**EA ID:** QM5_11419
**Slug:** 144-lwma-5smma-proximity-crossover-m5
**Source:** 978d3aba-1440-5aca-9aa4-b3176cf93873 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades a closed-bar M5 crossover between a 5-period SMMA and a 144-period LWMA. A long signal occurs when SMMA5 was at or below LWMA144 on the prior closed bar and closes above it on the latest closed bar; a short signal is the inverse. The latest closed price must still be within 10 pips of the LWMA144 anchor. The stop is the nearest confirmed fractal low for longs or fractal high for shorts within the lookback window, clamped to a 5-20 pip distance, and take profit is fixed at 2.0R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_lwma_period | 144 | 100-200 planned P3 sweep | Slow LWMA trend anchor period. |
| strategy_smma_period | 5 | 3-8 planned P3 sweep | Fast SMMA signal period. |
| strategy_proximity_pips | 10 | 5-20 planned P3 sweep | Maximum closed-price distance from LWMA144 at the crossover. |
| strategy_sl_lookback_bars | 15 | 2-50 | Bars scanned for the nearest confirmed fractal stop. |
| strategy_min_sl_pips | 5 | 1-20 | Minimum stop distance to avoid noise-tight stops. |
| strategy_max_sl_pips | 20 | 5-100 | Maximum stop distance cap from the card's P2 note. |
| strategy_tp_rr | 2.0 | 0.5-5.0 | Take-profit multiple of realised stop distance. |
| strategy_spread_cap_pips | 15 | 1-50 | Blocks entries only when live spread is wider than the cap. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card R3 names M5 DWX FX pairs and the registry assigns slot 0.
- GBPUSD.DWX - Card R3 names M5 DWX FX pairs and the registry assigns slot 1.

**Explicitly NOT for:**
- Index, metals, energy, and non-DWX symbols - the card is scoped to GBPUSD.DWX and EURUSD.DWX M5 FX data only.

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
| Trades / year / symbol | 300 |
| Typical hold time | Intraday scalping hold, typically minutes to a few hours, inferred from M5 scalping card body |
| Expected drawdown profile | Frequent small fixed-risk losses bounded by 5-20 pip stops |
| Regime preference | Trend-shift / short-term trend-following near the LWMA anchor |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 978d3aba-1440-5aca-9aa4-b3176cf93873
**Source type:** local PDF
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\408196018-144-Trend-Shift-Scalping-Forex-Trading-Strategy.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11419_144-lwma-5smma-proximity-crossover-m5.md`

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
| v1 | 2026-06-20 | Initial build from card | f69c5cc9-218f-4c46-8123-4afe5bb83ab3 |
