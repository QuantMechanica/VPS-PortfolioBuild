# QM5_10319_eia-oil-momo - Strategy Spec

**EA ID:** QM5_10319
**Slug:** eia-oil-momo
**Source:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9 (see `strategy-seeds/sources/fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

This EA trades only on scheduled EIA crude-oil inventory announcement proxy days, encoded as Wednesdays at 17:30 broker time. It measures the return of the 17:30-18:00 M30 bar and, at 21:00 broker time, enters long if that release-window return is positive or short if it is negative. It stays flat when the release-window bar is missing, when the current day range is too large versus D1 ATR, or when the entry spread is high versus recent EIA-day spreads. Any open trade is closed at 21:30 broker time, with no overnight holding.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 2-100 | ATR period used for the M30 emergency stop and D1 range filter. |
| `strategy_atr_sl_mult` | 0.80 | 0.10-5.00 | Emergency stop distance as a multiple of M30 ATR. |
| `strategy_daily_range_atr_mult` | 2.50 | 0.50-10.00 | Skip entry when the current day range before final-window entry exceeds this multiple of D1 ATR. |
| `strategy_spread_median_mult` | 1.50 | 0.50-10.00 | Maximum current spread as a multiple of the recent EIA-day median spread. |
| `strategy_spread_lookback_eia_days` | 20 | 3-60 | Number of prior EIA proxy days used for the spread median. |
| `strategy_history_days` | 90 | 30-365 | Bounded M30 history window for finding prior EIA proxy spread samples. |
| `strategy_eia_day_of_week` | 3 | 0-6 | Scheduled EIA proxy weekday, with Sunday=0 and Wednesday=3. |
| `strategy_release_hour_broker` | 17 | 0-23 | Broker-time hour of the release-window M30 bar. |
| `strategy_release_minute_broker` | 30 | 0 or 30 | Broker-time minute of the release-window M30 bar. |
| `strategy_final_entry_hour_broker` | 21 | 0-23 | Broker-time hour for final-window entry. |
| `strategy_final_entry_minute_broker` | 0 | 0 or 30 | Broker-time minute for final-window entry. |
| `strategy_final_close_hour_broker` | 21 | 0-23 | Broker-time hour for final-window close. |
| `strategy_final_close_minute_broker` | 30 | 0 or 30 | Broker-time minute for final-window close. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - active DWX crude-oil CFD equivalent for the source-native oil market.

**Explicitly NOT for:**
- `XAUUSD.DWX` - card allows gold only as a fallback robustness proxy, not as primary source evidence while oil is available.
- `XNGUSD.DWX` - energy commodity, but not crude oil inventory exposure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `D1` ATR for current-day disorder filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | 30 minutes |
| Expected drawdown profile | Event-driven intraday losses bounded by ATR emergency stop and same-session close. |
| Regime preference | News-driven intraday momentum |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
**Source type:** paper
**Pointer:** https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3822093
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10319_eia-oil-momo.md`

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
| v1 | 2026-06-12 | Initial build from card | 88468531-9e6e-4f22-bdb9-3ee82924399c |
