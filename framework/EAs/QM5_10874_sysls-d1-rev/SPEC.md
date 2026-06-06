# QM5_10874_sysls-d1-rev - Strategy Spec

**EA ID:** QM5_10874
**Slug:** `sysls-d1-rev`
**Source:** `66a6c726-c456-5899-be49-561e86612e8a` (see approved card artifact)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA fades large same-day moves near the configured session close. On each M15 bar at the configured close-minus entry minute, it compares the latest closed M15 close with the prior D1 close and normalizes that move by D1 ATR(20). If the normalized return is above +0.75 it enters short; if below -0.75 it enters long. It skips small current-day ranges, skips excessive spread relative to stop distance, uses ATR-based SL/TP, and exits at next session open plus 30 minutes unless the alternate next-close exit input is enabled.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 5-100 | D1 ATR period used for normalization, stop, and take profit. |
| `strategy_entry_threshold` | 0.75 | 0.50-1.00 | Absolute ATR-normalized D1 return threshold for reversal entry. |
| `strategy_sl_atr_mult` | 0.75 | 0.50-1.00 | Initial stop distance as a multiple of D1 ATR. |
| `strategy_tp_atr_mult` | 0.50 | 0.35-0.75 | Take-profit distance as a multiple of D1 ATR. |
| `strategy_min_tr_atr_mult` | 0.50 | 0.10-2.00 | Minimum current D1 true range as a multiple of D1 ATR. |
| `strategy_max_spread_stop_pct` | 8.0 | 0.0-25.0 | Maximum spread as percent of stop distance. |
| `strategy_entry_hour` | 23 | 0-23 | Broker hour for close-minus entry approximation. |
| `strategy_entry_minute` | 45 | 0-59 | Broker minute for close-minus entry approximation. |
| `strategy_exit_hour` | 0 | 0-23 | Broker hour for next-session-open exit approximation. |
| `strategy_exit_minute` | 30 | 0-59 | Broker minute for next-session-open-plus-30 exit. |
| `strategy_exit_next_close` | false | true/false | If true, use the card's alternate next-D1-close exit test. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX symbol with stable DWX coverage.
- `GBPUSD.DWX` - card-listed FX symbol with stable DWX coverage.
- `XAUUSD.DWX` - card-listed metal symbol with stable DWX coverage.
- `NDX.DWX` - card-listed index symbol with stable DWX coverage.
- `GDAXI.DWX` - DWX matrix DAX equivalent used because `GER40.DWX` is not present.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated DAX label, not present in `dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | D1 ATR and D1 current/prior OHLC |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Expected trade frequency | Medium-cadence daily close-threshold events |
| Typical hold time | About 45 minutes with default close-minus-15 to next-open-plus-30 mapping |
| Expected drawdown profile | Medium cadence with execution-timing and close-spread sensitivity |
| Regime preference | Mean-reversion after large same-day moves |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `66a6c726-c456-5899-be49-561e86612e8a`
**Source type:** archived X longpost
**Pointer:** `https://archive.ph/2025.12.24-233512/https%3A/x.com/systematicls/status/2003486775642321172?s=12`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10874_sysls-d1-rev.md`

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
| v1 | 2026-06-06 | Initial build from card | 50911e88-9ad1-4e35-b007-5858900424ad |
