# QM5_10143_rsi-momentum - Strategy Spec

**EA ID:** QM5_10143
**Slug:** rsi-momentum
**Source:** d3c009d7-a8d6-5251-b572-4777b207c2b9
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA computes Wilder RSI on completed D1 closes. It enters long when RSI crosses upward through the 50 centerline, and it can enter short when short mode is enabled and RSI crosses downward through the same centerline. A long exits after RSI has traded above the upper exit level and then crosses back below it, or when RSI crosses below the centerline. A short exits after RSI has traded below the lower exit level and then crosses back above it, or when RSI crosses above the centerline. Each entry uses an emergency stop at ATR(14) multiplied by the configured stop multiplier.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_timeframe | PERIOD_D1 | D1 default | Timeframe used for RSI and ATR reads. |
| strategy_rsi_period | 14 | 10, 14, 21, 28 | Wilder RSI period. |
| strategy_centerline | 50.0 | 50 | RSI momentum centerline. |
| strategy_upper_exit_level | 70.0 | 65, 70, 75 | Long extreme level that arms retrace exit. |
| strategy_lower_exit_level | 30.0 | 25, 30, 35 | Short extreme level that arms retrace exit. |
| strategy_shorts_enabled | true | false, true | Enables short entries and short exits. |
| strategy_atr_period | 14 | 14 default | ATR period for emergency stop distance. |
| strategy_atr_stop_mult | 3.0 | 2.5, 3.0, 4.0 | ATR multiple for emergency stop. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- AUDCAD.DWX - close-derived RSI rule is portable to DWX forex crosses.
- AUDCHF.DWX - close-derived RSI rule is portable to DWX forex crosses.
- AUDJPY.DWX - close-derived RSI rule is portable to DWX forex crosses.
- AUDNZD.DWX - close-derived RSI rule is portable to DWX forex crosses.
- AUDUSD.DWX - close-derived RSI rule is portable to DWX forex majors.
- CADCHF.DWX - close-derived RSI rule is portable to DWX forex crosses.
- CADJPY.DWX - close-derived RSI rule is portable to DWX forex crosses.
- CHFJPY.DWX - close-derived RSI rule is portable to DWX forex crosses.
- EURAUD.DWX - close-derived RSI rule is portable to DWX forex crosses.
- EURCAD.DWX - close-derived RSI rule is portable to DWX forex crosses.
- EURCHF.DWX - close-derived RSI rule is portable to DWX forex crosses.
- EURGBP.DWX - close-derived RSI rule is portable to DWX forex crosses.
- EURJPY.DWX - close-derived RSI rule is portable to DWX forex crosses.
- EURNZD.DWX - close-derived RSI rule is portable to DWX forex crosses.
- EURUSD.DWX - close-derived RSI rule is portable to DWX forex majors.
- GBPAUD.DWX - close-derived RSI rule is portable to DWX forex crosses.
- GBPCAD.DWX - close-derived RSI rule is portable to DWX forex crosses.
- GBPCHF.DWX - close-derived RSI rule is portable to DWX forex crosses.
- GBPJPY.DWX - close-derived RSI rule is portable to DWX forex crosses.
- GBPNZD.DWX - close-derived RSI rule is portable to DWX forex crosses.
- GBPUSD.DWX - close-derived RSI rule is portable to DWX forex majors.
- GDAXI.DWX - close-derived RSI rule is portable to liquid DWX index CFDs.
- NDX.DWX - card explicitly permits US large-cap DWX index exposure.
- NZDCAD.DWX - close-derived RSI rule is portable to DWX forex crosses.
- NZDCHF.DWX - close-derived RSI rule is portable to DWX forex crosses.
- NZDJPY.DWX - close-derived RSI rule is portable to DWX forex crosses.
- NZDUSD.DWX - close-derived RSI rule is portable to DWX forex majors.
- SP500.DWX - card permits SP500.DWX, with T6 live-routing caveat handled later.
- UK100.DWX - close-derived RSI rule is portable to liquid DWX index CFDs.
- USDCAD.DWX - close-derived RSI rule is portable to DWX forex majors.
- USDCHF.DWX - close-derived RSI rule is portable to DWX forex majors.
- USDJPY.DWX - close-derived RSI rule is portable to DWX forex majors.
- WS30.DWX - card explicitly permits US large-cap DWX index exposure.
- XAGUSD.DWX - card permits metals CFDs.
- XAUUSD.DWX - card permits metals CFDs.
- XNGUSD.DWX - close-derived RSI rule is portable to registered DWX energy CFDs.
- XTIUSD.DWX - card permits oil CFDs.

**Explicitly NOT for:**
- Any symbol absent from `framework/registry/dwx_symbol_matrix.csv` - the framework magic resolver only accepts registered DWX symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 24 |
| Typical hold time | Not specified in card frontmatter; RSI centerline-to-extreme retrace implies multi-day holds on D1. |
| Expected drawdown profile | Fixed-risk D1 momentum profile, bounded by the V5 risk model and ATR emergency stop. |
| Regime preference | Momentum and trend-following regimes. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d3c009d7-a8d6-5251-b572-4777b207c2b9
**Source type:** Raposa.Trade educational article
**Pointer:** https://raposa.trade/blog/4-simple-rsi-trading-strategies-you-can-use-today/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10143_rsi-momentum.md`

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
| v1 | 2026-06-10 | Initial build from card | 82f73f85-c573-4bef-921b-e1e9cfe102e1 |
