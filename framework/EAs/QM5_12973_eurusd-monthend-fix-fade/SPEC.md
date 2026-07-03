# QM5_12973_eurusd-monthend-fix-fade - Strategy Spec

**EA ID:** QM5_12973
**Slug:** `eurusd-monthend-fix-fade`
**Source:** `CEO-ANOMALY-SLATE-2026-07-03` (see approved farm card)
**Author of this spec:** Codex
**Last revised:** 2026-07-03

---

## 1. Strategy Logic

The EA trades the month-end WMR 16:00 London fix reversion anomaly on EURUSD and GBPUSD. On the last weekday of the calendar month, it compares the M5 close at 16:00 London with the M5 close at 15:00 London. If the absolute move is at least 0.5 times the prior D1 ATR(14), it enters after the fix window in the opposite direction of that move.

The strategy has no profit target. It uses a 1.0 times M5 ATR(14) protective stop at entry and exits any open position at 18:00 London on the same trading day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fix_start_london_hhmm` | 1500 | 0000-2359 | London-time M5 bar used as the start of the measured pre-fix move. |
| `strategy_fix_end_london_hhmm` | 1600 | 0000-2359 | London-time M5 bar used as the end of the measured pre-fix move. |
| `strategy_entry_after_hhmm` | 1605 | 0000-2359 | Earliest London time for the post-fix fade entry. |
| `strategy_entry_until_hhmm` | 1700 | 0000-2359 | Last London time at which a new fade entry may be opened. |
| `strategy_exit_london_hhmm` | 1800 | 0000-2359 | London time-stop for open positions. |
| `strategy_daily_atr_period` | 14 | >0 | D1 ATR lookback used for the trigger threshold. |
| `strategy_m5_atr_period` | 14 | >0 | M5 ATR lookback used for the protective stop. |
| `strategy_trigger_atr_frac` | 0.5 | >0 | Required fraction of D1 ATR for the 15:00-16:00 London move. |
| `strategy_stop_atr_mult` | 1.0 | >0 | Protective stop multiple of M5 ATR. |
| `strategy_max_spread_points` | 0 | >=0 | Maximum spread in points; 0 disables the guard so .DWX zero spread does not block. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major WMR-fix FX pair with deep liquidity and explicit card coverage.
- `GBPUSD.DWX` - major WMR-fix FX pair with deep liquidity and explicit card coverage.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the WMR-fix rebalancing anomaly is an FX microstructure effect.
- FX pairs outside the card list - no card approval for broader portable expansion in this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | D1 ATR(14) for trigger threshold; M5 ATR(14) for stop |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | About 2 hours, from shortly after 16:05 London to 18:00 London |
| Expected drawdown profile | Low-frequency intraday mean-reversion drawdown, concentrated around month-end flow days. |
| Regime preference | Calendar-monthend / fix-anomaly mean reversion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `CEO-ANOMALY-SLATE-2026-07-03`
**Source type:** paper
**Pointer:** Evans (2018), Ito and Yamada NBER fix-dynamics work, and execution-study evidence cited in approved card at `D:\QM\strategy_farm\artifacts\cards_approved\QM5_12973_eurusd-monthend-fix-fade.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12973_eurusd-monthend-fix-fade.md`

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
| v1 | 2026-07-03 | Initial build from approved card | 1b97fcd1-d1f5-4df2-bb12-433f44b8c0c4 |
