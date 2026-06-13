# QM5_10626_mql5-night-sto — Strategy Spec

**EA ID:** QM5_10626
**Slug:** mql5-night-sto
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

This EA trades only during the broker-time night window from 21:00 inclusive to 06:00 exclusive. On each completed M15 bar it reads the Stochastic main line with 5/3/3 parameters. It opens long when the main line is below 30 and opens short when the main line is above 70. Exits are the source fixed 40 pip stop loss and 20 pip take profit, with V5 Friday close and kill-switch exits left active.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_timeframe` | `PERIOD_M15` | MT5 timeframe enum | Timeframe used for the Stochastic signal. |
| `strategy_stoch_k_period` | `5` | `1+` | Stochastic K period. |
| `strategy_stoch_d_period` | `3` | `1+` | Stochastic D period. |
| `strategy_stoch_slowing` | `3` | `1+` | Stochastic slowing value. |
| `strategy_stoch_oversold` | `30.0` | `0-100` | Main-line threshold for long entries. |
| `strategy_stoch_overbought` | `70.0` | `0-100` | Main-line threshold for short entries. |
| `strategy_stop_pips` | `40` | `1+` | Fixed stop loss in pips. |
| `strategy_take_pips` | `20` | `1+` | Fixed take profit in pips. |
| `strategy_night_start_hour` | `21` | `0-23` | Broker hour where the entry window starts. |
| `strategy_night_end_hour` | `6` | `0-23` | Broker hour where the entry window ends. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — source-tested FX pair and directly listed by the approved card.
- `GBPUSD.DWX` — major FX pair listed by the approved card for portable M15 testing.
- `USDJPY.DWX` — major FX pair listed by the approved card for portable M15 testing.

**Explicitly NOT for:**
- `SP500.DWX` — the approved card is an FX night-session strategy, not an equity-index strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | minutes to hours, bounded by fixed SL/TP and Friday close |
| Expected drawdown profile | mean-reversion losses can cluster in directional night sessions |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_10626_mql5-night-sto.md`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10626_mql5-night-sto.md`

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
| v1 | 2026-06-13 | Initial build from card | d25af5db-63d9-467f-92f8-afbec027ff46 |
