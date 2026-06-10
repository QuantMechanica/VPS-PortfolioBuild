<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_1588_aa-tsmom-vol12 — Strategy Spec

**EA ID:** QM5_1588
**Slug:** `aa-tsmom-vol12`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `strategy-seeds/sources/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

Each symbol is positioned long if its trailing 12-month return (close-to-close, 252 D1 bars ago) is positive, and short if negative. If the return is exactly zero or insufficient history is available, the EA holds cash (no position). Position size is scaled by the inverse of the symbol's realized annualized volatility (standard deviation of daily log-returns over the last 20 D1 bars, annualized by ×√252), targeting a 12% annual volatility contribution, capped at 1× notional (no leverage). The initial stop-loss is placed 3× ATR(20, D1) from entry. The position is held until the 12-month return sign reverses, at which point the EA closes and reverses direction on the next new D1 bar.

D1-native: MN1 bars are untestable in the MT5 tester for DWX custom symbols; 252 D1 bars proxy the 12-month lookback.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_days` | 252 | 180–504 | Trailing return lookback in D1 bars (~12 months) |
| `strategy_vol_period` | 20 | 10–60 | Realized-vol window in D1 bars for inverse-vol sizing |
| `strategy_vol_target` | 0.12 | 0.05–0.25 | Annual volatility target (12% = 0.12) |
| `strategy_atr_period` | 20 | 10–50 | ATR period for stop-loss (D1 bars) |
| `strategy_atr_sl_mult` | 3.0 | 1.5–6.0 | Stop-loss = N × ATR(20, D1) |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 proxy; backtest-only (broker does not route live orders); major US large-cap trend carrier
- `NDX.DWX` — Nasdaq 100; liquid US tech-heavy index; strong TSMOM signal historically
- `WS30.DWX` — Dow Jones 30; US blue-chip index; broad US equity exposure
- `GDAXI.DWX` — DAX 40; primary European equity index; diversified from US basket
- `UK100.DWX` — FTSE 100; UK large-cap; additional international diversification
- `XAUUSD.DWX` — Gold; classic managed-futures TSMOM asset with trend properties

**Explicitly NOT for:**
- FX pairs — TSMOM applied to currencies requires interest-rate cost model not yet implemented
- `SP500.DWX` for live T6 deployment — broker does not route orders; requires parallel NDX/WS30 validation before AutoTrading enable

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | None (CopyRates explicitly targets PERIOD_D1) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (D1 chart) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 (one entry per trend episode; signal changes ~monthly) |
| Typical hold time | 3–8 weeks per directional trend episode |
| Expected drawdown profile | Moderate; trend-following drawdowns during range/reversal periods |
| Regime preference | Trending (sustained directional momentum over 12-month horizon) |
| Win rate target (qualitative) | low–medium (large winners offset frequent small losses) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** blog / peer-reviewed research summary
**Pointer:** Wesley Gray, PhD, "Time Series Momentum, Volatility Scaling, and Crisis Alpha", Alpha Architect, 2016-12-22
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1588_aa-tsmom-vol12.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-10 | Initial build from card | e58e6d09-3cf8-4fc5-8313-4c9d4dd9ab04 |
