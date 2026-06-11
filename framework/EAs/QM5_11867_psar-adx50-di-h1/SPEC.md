# QM5_11867_psar-adx50-di-h1 - Strategy Spec

**EA ID:** QM5_11867
**Slug:** psar-adx50-di-h1
**Source:** 3c77a80c-f428-57eb-a720-51347dd823b3 (see local PDF archive)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades H1 forex trend alignment between Parabolic SAR and ADX directional movement. A long signal occurs on the close of the first bar where +DI(50) is above -DI(50) and the PSAR dot is below that closed candle. A short signal occurs on the close of the first bar where -DI(50) is above +DI(50) and the PSAR dot is above that closed candle. Initial exits are 2x ATR(14) stop loss and 4x ATR(14) take profit; an open trade also closes when PSAR flips to the opposite side of current price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_adx_period | 50 | >= 1 | Period for ADX +DI and -DI confirmation. |
| strategy_psar_step | 0.02 | > 0 and < strategy_psar_maximum | Parabolic SAR acceleration step. |
| strategy_psar_maximum | 0.20 | > strategy_psar_step | Parabolic SAR maximum acceleration. |
| strategy_atr_period | 14 | >= 1 | ATR period for initial stop and target distance. |
| strategy_atr_sl_mult | 2.0 | > 0 | Stop-loss distance as ATR multiple. |
| strategy_atr_tp_mult | 4.0 | > 0 | Take-profit distance as ATR multiple. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card target symbol; liquid major forex pair with H1 DWX history.
- GBPUSD.DWX - Card target symbol; liquid major forex pair with H1 DWX history.
- USDJPY.DWX - Card target symbol; liquid major forex pair with H1 DWX history.
- AUDUSD.DWX - Card target symbol; liquid major forex pair with H1 DWX history.

**Explicitly NOT for:**
- Non-forex `.DWX` symbols - The approved card is forex-specific and lists only major FX pairs.
- Forex pairs outside the registered basket - Not registered for this EA, so magic resolution should reject them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 20 |
| Typical hold time | not specified by card; expected hours to days until 2x ATR stop, 4x ATR target, or PSAR flip |
| Expected drawdown profile | not specified by card; trend-following ATR-defined risk per trade |
| Regime preference | trend-following forex regimes with DI direction confirmation |
| Win rate target (qualitative) | medium, with 2.0 reward-to-risk from ATR stop/target |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3c77a80c-f428-57eb-a720-51347dd823b3
**Source type:** book / local PDF archive
**Pointer:** Thomas Carter, 20 Forex Trading Strategies (1 Hour Time Frame), 2014. URL: local PDF archive
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11867_psar-adx50-di-h1.md`

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
| v1 | 2026-06-11 | Initial build from card | fae52475-4dff-4e43-b7ed-9b8f9d7ee78f |
