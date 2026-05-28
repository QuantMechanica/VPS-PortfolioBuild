# QM5_10146_tii-meanrev — Strategy Spec

**EA ID:** QM5_10146
**Slug:** `tii-meanrev`
**Source:** `d3c009d7-a8d6-5251-b572-4777b207c2b9` (see `strategy-seeds/sources/d3c009d7-a8d6-5251-b572-4777b207c2b9/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-26

---

## 1. Strategy Logic

The EA calculates a Trend Intensity Index as `200 * count(Close > SMA(Close, P), P/2) / P` on completed D1 bars. It enters long when TII is at or below the long threshold and, when enabled, enters short when TII is at or above the short threshold. Long positions close when TII crosses back up through the centerline; short positions close when TII crosses back down through the centerline. A fixed emergency stop is placed at `strategy_atr_stop_mult * ATR(strategy_atr_period)` and V5 handles fixed-risk sizing.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tii_period` | 60 | 30, 45, 60, 90 | Lookback period for SMA and TII calculation. |
| `strategy_enter_long` | 20.0 | 10.0-30.0 | Long entry threshold for oversold TII readings. |
| `strategy_enter_short` | 80.0 | 70.0-90.0 | Short entry threshold for overbought TII readings. |
| `strategy_exit_centerline` | 50.0 | 45.0-55.0 | Mean-reversion centerline used for exits. |
| `strategy_shorts_enabled` | true | true/false | Enables symmetric short entries and exits. |
| `strategy_atr_period` | 14 | fixed research default | ATR period for emergency stop distance. |
| `strategy_atr_stop_mult` | 3.0 | 2.0-4.0 | ATR multiplier for the emergency stop. |
| `strategy_max_spread_points` | 0 | 0 or symbol-specific cap | Optional spread cap; 0 uses the framework/default broker guard only. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `AUDCAD.DWX` — registered in magic_numbers.csv for this EA
- `AUDCHF.DWX` — registered in magic_numbers.csv for this EA
- `AUDJPY.DWX` — registered in magic_numbers.csv for this EA
- `AUDNZD.DWX` — registered in magic_numbers.csv for this EA
- `AUDUSD.DWX` — registered in magic_numbers.csv for this EA
- `CADCHF.DWX` — registered in magic_numbers.csv for this EA
- `CADJPY.DWX` — registered in magic_numbers.csv for this EA
- `CHFJPY.DWX` — registered in magic_numbers.csv for this EA
- `EURAUD.DWX` — registered in magic_numbers.csv for this EA
- `EURCAD.DWX` — registered in magic_numbers.csv for this EA
- `EURCHF.DWX` — registered in magic_numbers.csv for this EA
- `EURGBP.DWX` — registered in magic_numbers.csv for this EA
- `EURJPY.DWX` — registered in magic_numbers.csv for this EA
- `EURNZD.DWX` — registered in magic_numbers.csv for this EA
- `EURUSD.DWX` — registered in magic_numbers.csv for this EA
- `GBPAUD.DWX` — registered in magic_numbers.csv for this EA
- `GBPCAD.DWX` — registered in magic_numbers.csv for this EA
- `GBPCHF.DWX` — registered in magic_numbers.csv for this EA
- `GBPJPY.DWX` — registered in magic_numbers.csv for this EA
- `GBPNZD.DWX` — registered in magic_numbers.csv for this EA
- `GBPUSD.DWX` — registered in magic_numbers.csv for this EA
- `GDAXI.DWX` — registered in magic_numbers.csv for this EA
- `NDX.DWX` — registered in magic_numbers.csv for this EA
- `NZDCAD.DWX` — registered in magic_numbers.csv for this EA
- `NZDCHF.DWX` — registered in magic_numbers.csv for this EA
- `NZDJPY.DWX` — registered in magic_numbers.csv for this EA
- `NZDUSD.DWX` — registered in magic_numbers.csv for this EA
- `SP500.DWX` — registered in magic_numbers.csv for this EA
- `UK100.DWX` — registered in magic_numbers.csv for this EA
- `USDCAD.DWX` — registered in magic_numbers.csv for this EA
- `USDCHF.DWX` — registered in magic_numbers.csv for this EA
- `USDJPY.DWX` — registered in magic_numbers.csv for this EA
- `WS30.DWX` — registered in magic_numbers.csv for this EA
- `XAGUSD.DWX` — registered in magic_numbers.csv for this EA
- `XAUUSD.DWX` — registered in magic_numbers.csv for this EA
- `XNGUSD.DWX` — registered in magic_numbers.csv for this EA
- `XTIUSD.DWX` — registered in magic_numbers.csv for this EA

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Cadence note | see card body |
| Typical hold time | days |
| Expected drawdown profile | mean-reversion drawdown bounded by emergency ATR stop and V5 fixed risk |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d3c009d7-a8d6-5251-b572-4777b207c2b9`
**Source type:** blog
**Pointer:** `https://raposa.trade/blog/4-ways-to-trade-the-trend-intensity-indicator/`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10146_tii-meanrev.md`

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
| v1 | 2026-05-26 | Initial build from card | a2938b1d-acee-473b-b2f0-85264c899090 |
