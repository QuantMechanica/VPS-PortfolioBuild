# QM5_1249_hsu-carry-stop - Strategy Spec

**EA ID:** QM5_1249
**Slug:** hsu-carry-stop
**Source:** afab7a6f-c3c8-51ae-a609-f376744beb8e
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades a six-symbol FX carry basket on a D1 monthly rebalance. It reads a deterministic monthly rates CSV, computes base-currency rate minus quote-currency rate for each pair, then goes long symbols in the top two positive differentials and short symbols in the bottom two negative differentials. Existing positions are checked at each monthly rebalance and closed when their symbol leaves the selected rank set or the differential crosses through zero. Every entry receives a fixed stop at 2.5 x ATR(D1,20), and a symbol stopped during the current month is not re-entered until a later rebalance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_rates_csv_path | QM5_1249_fx_monthly_rates.csv | terminal or common Files path | Deterministic monthly short-rate CSV, columns date,USD,EUR,GBP,JPY,AUD,NZD,CAD,CHF. |
| strategy_rank_count | 2 | 1-3 | Number of top positive and bottom negative differentials eligible for entry. |
| strategy_stale_calendar_days | 45 | greater than 0 | Maximum calendar age of the latest rates observation before the EA stays flat. |
| strategy_atr_period_d1 | 20 | greater than 0 | D1 ATR period used for the fixed stop. |
| strategy_atr_stop_mult | 2.5 | greater than 0 | ATR multiple used for the fixed stop. |
| strategy_rebalance_months | 1 | greater than 0 | Rebalance cadence in months; baseline is monthly. |
| strategy_rebalance_day_limit | 7 | 1-31 | Latest calendar day allowed for a month-start rebalance tick. |
| strategy_max_spread_pips | 0.0 | 0 disables, otherwise greater than 0 | Optional absolute spread cap; zero spread is allowed for DWX tests. |

---

## 3. Symbol Universe

**Designed for:**
- AUDJPY.DWX - Card-listed JPY carry pair with AUD base-rate exposure.
- NZDJPY.DWX - Card-listed JPY carry pair with NZD base-rate exposure.
- GBPJPY.DWX - Card-listed JPY carry pair with GBP base-rate exposure.
- USDJPY.DWX - Card-listed JPY carry pair with USD base-rate exposure.
- AUDUSD.DWX - Card-listed USD cross with AUD base-rate exposure.
- NZDUSD.DWX - Card-listed USD cross with NZD base-rate exposure.

**Explicitly NOT for:**
- Non-FX symbols - the card defines FX carry from short-rate differentials.
- FX symbols outside the six registered slots - no card ranking rule or magic slot is allocated for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | ATR(D1,20) only |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) in the framework OnTick path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Not specified in card frontmatter; monthly rebalance implies low turnover. |
| Typical hold time | Not specified in card frontmatter; expected to be weeks to months. |
| Expected drawdown profile | Not specified in card frontmatter; fixed ATR stop constrains per-trade loss. |
| Regime preference | FX carry / rate-differential regime. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** afab7a6f-c3c8-51ae-a609-f376744beb8e
**Source type:** paper
**Pointer:** https://ssrn.com/abstract=3158101 and `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1249_hsu-carry-stop.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1249_hsu-carry-stop.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | 4eaee3cd-750a-4cbd-b2a7-a8c4418f10af |
