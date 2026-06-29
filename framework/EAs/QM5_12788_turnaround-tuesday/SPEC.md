# QM5_12788_turnaround-tuesday - Strategy Spec

**EA ID:** QM5_12788
**Slug:** `turnaround-tuesday`
**Source:** `sm-mining-sm012-turnaround-tuesday-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

---

## 1. Strategy Logic

This EA trades a weekly FX reversal after an unusually directional Monday. On the first Tuesday H1 bar, it measures Monday's H1 high-low range, Monday's close, and the prior Friday close. It buys when Monday closed below Friday and in the lower 40% of Monday's range; it sells when Monday closed above Friday and in the upper 40% of Monday's range. The Monday range must be at least 0.5 times D1 ATR(20), each trade has a D1 ATR stop, and any open trade is closed on Tuesday at 22:00 broker time or on Wednesday if still open.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 2-100 | D1 ATR period for Monday-range gate and stop distance. |
| `strategy_min_monday_atr` | 0.50 | 0.10-3.00 | Minimum Monday range as a multiple of D1 ATR. |
| `strategy_close_zone_pct` | 40.0 | 5.0-49.0 | Required close location in the lower or upper part of Monday's range. |
| `strategy_sl_atr_mult` | 1.00 | 0.25-5.00 | Stop distance as a D1 ATR multiple. |
| `strategy_sl_floor_atr_mult` | 0.75 | 0.25-5.00 | Minimum stop distance as a D1 ATR multiple. |
| `strategy_tp_r` | 1.50 | 0.00-3.00 | Optional take-profit as R multiple; 0 disables TP. |
| `strategy_entry_start_hour` | 0 | 0-23 | First Tuesday broker-hour allowed for entry. |
| `strategy_entry_end_hour` | 1 | 0-23 | Last Tuesday broker-hour allowed for entry. |
| `strategy_exit_hour_tuesday` | 22 | 0-23 | Tuesday broker-hour time exit. |
| `strategy_max_hold_hours` | 30 | 1-72 | Failsafe maximum hold after entry. |
| `strategy_history_bars_h1` | 120 | 72-168 | Bounded H1 lookback for Monday and Friday reference bars. |
| `strategy_max_spread_points` | 80 | 0-500 | Skip entry when modeled spread exceeds this many points; zero spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - validated lead symbol from the mined SM_012 campaign.
- `EURUSD.DWX` - optional FX-broad test named by the card for the same Tuesday reversal anomaly.
- `USDCAD.DWX` - optional FX-broad test named by the card for the same Tuesday reversal anomaly.

**Explicitly NOT for:**
- `XAUUSD.DWX` - card is an FX weekly calendar anomaly, not a metal session drift strategy.
- `XTIUSD.DWX` - commodity weekend and inventory effects are different structural drivers.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `PERIOD_D1` ATR(20) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | `22 hours or less` |
| Expected drawdown profile | `Moderate FX calendar-reversal drawdowns, expected DD around 12% in research prior.` |
| Regime preference | `weekly calendar mean-reversion after directional Mondays` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `sm-mining-sm012-turnaround-tuesday-2026`
**Source type:** `OWNER campaign / local source audit`
**Pointer:** `Dropbox/FTMO March 2026/SM_Portfolio_Deploy/Experts/FTMO_SM_012_TurnaroundTue.mq5`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12788_turnaround-tuesday.md`

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
| v1 | 2026-06-29 | Initial build from card | ef8d5a9c-9807-464f-9df3-130315178d8a |
