<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_10892_el-d3-t11-month-end-rev — Strategy Spec

**EA ID:** QM5_10892
**Slug:** `el-d3-t11-month-end-rev`
**Source:** `` (Etula-Rinne-Suominen-Vaittinen 2020 RFS; Melvin-Prins 2015)
**Author of this spec:** Development
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

On the third-to-last trading day of each calendar month, the EA computes the month-to-date (MTD) return for each of seven USD-major forex pairs (EURUSD, GBPUSD, AUDUSD, NZDUSD, USDJPY, USDCHF, USDCAD). MTD return is measured as the close of the last completed D1 bar divided by the open of the first D1 bar of the current month, minus one. The seven pairs are ranked by MTD return in descending order. The two highest-returning pairs (overperformers) receive a SELL entry; the two lowest-returning pairs (underperformers) receive a BUY entry; the middle three receive no trade. Each instance of the EA runs on exactly one symbol and fires only if that symbol falls in the top-two or bottom-two bucket. All open positions are closed at the end of the first trading day of the new month (detected as the second D1 bar of the new calendar month). A 2x Daily ATR(14) hard stop-loss is placed on each leg.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 7-28 | ATR period (D1) for stop-loss calculation |
| `strategy_atr_sl_mult` | 2.0 | 1.0-4.0 | ATR multiplier for stop-loss distance |
| `strategy_max_spread_points` | 0 | 0-100 | Skip entry if spread exceeds this (0 = disabled) |

---

## 3. Symbol Universe

Each of the seven USD-major pairs listed below runs as an independent EA instance. Cross-sectional ranking uses all seven pairs simultaneously.

**Designed for:**
- `EURUSD.DWX` — slot 0; EUR/USD is the most liquid G8 pair, strong MTD signal fidelity
- `GBPUSD.DWX` — slot 1; GBP/USD; high liquidity, significant institutional rebalancing flows
- `AUDUSD.DWX` — slot 2; AUD/USD; commodity-linked, diversifies the basket
- `NZDUSD.DWX` — slot 3; NZD/USD; correlated with AUD but independent rebalancing pressure
- `USDJPY.DWX` — slot 4; USD/JPY; safe-haven dynamics add cross-sectional contrast
- `USDCHF.DWX` — slot 5; USD/CHF; safe-haven franc, distinct rebalancing profile
- `USDCAD.DWX` — slot 6; USD/CAD; commodity-linked, oil-driven diversification

**Explicitly NOT for:**
- Any non-DWX symbol — tester data not available
- Cross pairs (EURGBP, GBPJPY, etc.) — excluded from this basket by card design

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | ATR(14) on D1 for stop distance |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 (one per month-end cycle when symbol is in top/bottom group) |
| Typical hold time | 2-4 calendar days (D-3 entry to M+1 first-day exit) |
| Expected drawdown profile | Low intra-trade; 10% max per card spec |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** (Etula-Rinne-Suominen-Vaittinen 2020 RFS; Melvin-Prins 2015)
**Source type:** paper
**Pointer:** Etula E., Rinne K., Suominen M. & Vaittinen L. (2020). "Dash for Cash: Monthly Market Impact of Institutional Liquidity Needs." Review of Financial Studies 33(1), 75-111. Supporting: Melvin & Prins (2015), Journal of Financial Markets 22.
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10892_el-d3-t11-month-end-rev.md`

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
| v1 | 2026-06-12 | Initial build from card | 84e077b0-c262-4a61-a33f-80fd10c55334 |
