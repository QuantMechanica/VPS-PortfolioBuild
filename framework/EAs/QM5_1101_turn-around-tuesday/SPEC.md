# QM5_1101_turn-around-tuesday - Strategy Spec

**EA ID:** QM5_1101
**Slug:** turn-around-tuesday
**Source:** none_provided (see approved card source list)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades the first D1 bar that follows the first trading session after Friday. If that reference session closed more than `strategy_monday_threshold_pct` below the prior trading close, the EA enters long; if it closed more than the threshold above the prior trading close, the EA enters short. The position uses a hard stop at `strategy_max_stop_pct` from entry and exits after `strategy_max_hold_d1_bars` D1 bars. There is no regime filter.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_monday_threshold_pct | 0.003 | 0.0-0.05 | Absolute reference-day return threshold that triggers a reversal entry. |
| strategy_enable_long | true | true/false | Enables long entries after a down reference day. |
| strategy_enable_short | true | true/false | Enables short entries after an up reference day. |
| strategy_max_stop_pct | 0.015 | 0.001-0.10 | Hard stop distance from entry price as a price percentage. |
| strategy_max_hold_d1_bars | 1 | 1-5 | Maximum D1 bars to hold before strategy close. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq 100 index exposure from the card's portable major-index basket.
- WS30.DWX - Dow 30 index exposure from the card's portable major-index basket.
- GDAXI.DWX - DAX index exposure from the card's portable major-index basket.
- UK100.DWX - FTSE 100 index exposure from the card's portable major-index basket.

**Explicitly NOT for:**
- Forex and metals symbols - the card specifies major equity index day-of-week effects, not FX or commodity seasonality.
- SP500.DWX - valid DWX custom symbol, but not listed in this card's Symbol section.

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
| Trades / year / symbol | 2 in frontmatter; strategy body states 50-80 |
| Typical hold time | 1 D1 bar |
| Expected drawdown profile | Short holding-period reversal drawdowns, bounded by a 1.5% hard stop before risk sizing. |
| Regime preference | Short-term reversal / day-of-week effect, no explicit regime filter. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** none_provided
**Source type:** paper
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1101_turn-around-tuesday.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1101_turn-around-tuesday.md`

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
| v1 | 2026-06-07 | Initial build from card | 177db9f4-8349-417c-9dd9-6af51c809664 |
