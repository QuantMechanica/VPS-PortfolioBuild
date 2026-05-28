# QM5_10260_cieslak-fomc-cycle-idx - Strategy Spec

**EA ID:** QM5_10260
**Slug:** `cieslak-fomc-cycle-idx`
**Source:** `afab7a6f-c3c8-51ae-a609-f376744beb8e` (see `strategy-seeds/sources/afab7a6f-c3c8-51ae-a609-f376744beb8e/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-27

---

## 1. Strategy Logic

The EA trades long only during even-numbered weeks of the FOMC cycle. It finds the most recent scheduled FOMC meeting date from a static table, computes `cycle_week = floor((today - last_fomc_date) / 7 days)`, and enters on Monday morning when the cycle week is 0, 2, 4, 6, or 8. If that Monday is a US market holiday, the EA may enter on Tuesday morning instead, and it exits any open position on Friday at the configured close hour.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period_d1` | 14 | 1-100 | Daily ATR period used for the hard stop. |
| `strategy_atr_sl_mult` | 3.0 | 0.1-10.0 | ATR multiplier for the stop below long entry. |
| `strategy_entry_start_hour` | 0 | 0-23 | Broker hour when Monday or holiday-Tuesday entries may start. |
| `strategy_entry_end_hour` | 6 | 1-24 | Broker hour when the entry window ends. |
| `strategy_friday_exit_hour` | 21 | 0-23 | Broker hour for Friday time-stop exit. |
| `strategy_max_cycle_week` | 8 | 0-8 | Highest even FOMC-cycle week allowed for entry. |
| `strategy_max_spread_points` | 0 | 0+ | Maximum spread in points; 0 disables this strategy spread cap. |
| `strategy_allow_tuesday_holiday_entry` | true | true/false | Allows Tuesday entry when Monday was a listed US market holiday. |
| `strategy_allow_fomc_hold` | true | true/false | Documents the card-authorized FOMC hold override. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - US Nasdaq 100 index exposure, live-routable in the R3 basket.
- `WS30.DWX` - US Dow 30 index exposure, live-routable in the R3 basket.
- `SP500.DWX` - S&P 500 exposure matching the source paper most directly; backtest-only per card caveat.

**Explicitly NOT for:**
- `GDAXI.DWX` - not part of the card's US-index universe.
- `UK100.DWX` - not part of the card's US-index universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `PERIOD_D1` ATR(14) and calendar-day FOMC-cycle computation |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | `about 5 trading days` |
| Expected drawdown profile | `weekly index premium with ATR-defined hard stops and portfolio MAX_DD trip` |
| Regime preference | `news-driven calendar premium` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `afab7a6f-c3c8-51ae-a609-f376744beb8e`
**Source type:** `paper`
**Pointer:** `https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2358090`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10260_cieslak-fomc-cycle-idx.md`

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
| v1 | 2026-05-27 | Initial build from card | 1cc6bc1b-062c-422b-b4ea-9484d88ad9e5 |
