<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_11379_144lwma-5smma-cross-m5 — Strategy Spec

**EA ID:** QM5_11379
**Slug:** 144lwma-5smma-cross-m5
**Source:** 2d326962-8dcc-52f4-b483-09178a05f419
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades a closed-bar moving-average cross on M5. A long entry is opened when SMMA(5) crosses above LWMA(144), and a short entry is opened when SMMA(5) crosses below LWMA(144). The close of the cross candle must remain within 10 pips of LWMA(144), so entries are skipped when price is already extended. The stop is the most recent opposite-side Williams fractal within the lookback window, capped by the card's pip limits, and the take profit is fixed at 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_smma_period | 5 | >= 1 | Fast smoothed moving average period used as the trigger line. |
| strategy_lwma_period | 144 | >= 1 | Slow linear-weighted moving average period used as the trend anchor. |
| strategy_proximity_pips | 10 | > 0 | Maximum absolute distance between the cross candle close and LWMA(144). |
| strategy_fractal_lookback | 10 | >= 2 | Closed bars scanned for the most recent opposite-side Williams fractal. |
| strategy_sl_cap_pips | 20 | > 0 | Maximum realised stop distance after applying the P2 cap. |
| strategy_fractal_max_pips | 15 | > 0 | Skip trades when the selected fractal is farther than this from entry. |
| strategy_tp_rr | 2.0 | > 0 | Take-profit distance as a multiple of the realised stop distance. |
| strategy_spread_cap_pips | 15 | > 0 | Blocks only genuinely wide positive spreads above this level. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- GBPUSD.DWX — explicitly listed by the approved card and present in `dwx_symbol_matrix.csv`.
- EURUSD.DWX — explicitly listed by the approved card and present in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- Non-FX index, metal, energy, and cross-asset `.DWX` symbols — the source card is an M5 FX scalping rule and does not authorize broad-asset expansion.
- FX symbols outside GBPUSD.DWX and EURUSD.DWX — the approved R3 row names only these two instruments.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Typical hold time | Not specified in frontmatter; card describes M5 scalping with SL/2R TP, so expected hold is intraday. |
| Expected drawdown profile | Not specified in frontmatter; bounded per-trade fixed-risk trend-following scalper. |
| Regime preference | Trend-following / trend-shift continuation. |
| Win rate target (qualitative) | Medium; fixed 2R target allows sub-50% viability if losses are controlled. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 2d326962-8dcc-52f4-b483-09178a05f419
**Source type:** local PDF / forexmt4indicators.com article archive
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\408196018-144-Trend-Shift-Scalping-Forex-Trading-Strategy.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11379_144lwma-5smma-cross-m5.md`

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
| v1 | 2026-06-20 | Initial build from card | 655c87f8-d288-4a2c-8c35-d76323afc628 |
