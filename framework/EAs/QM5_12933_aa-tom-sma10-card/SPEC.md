# QM5_12933_aa-tom-sma10-card - Strategy Spec

**EA ID:** QM5_12933
**Slug:** `aa-tom-sma10-card`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `sources/alpha-architect-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA trades a long-only monthly timing rule on a D1 chart. It normalizes each completed calendar month into 21 trading-day buckets, reads the selected bucket close, and compares that close with the average of the prior 10 selected-bucket monthly closes. It enters long when the selected close is above the 10-month SMA, and closes any long position when the selected close is at or below the SMA. The default bucket is 21, so the signal is based on the completed month ending at the last trading day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_months` | 10 | 1-20 | Number of prior selected-bucket monthly closes used in the SMA. |
| `strategy_bucket_day` | 21 | 1-21 | Normalized monthly trading-day bucket used for signal evaluation. |
| `strategy_bucket_count` | 21 | 1-32 | Number of normalized trading-day buckets per calendar month. |
| `strategy_atr_period` | 20 | 1-100 | D1 ATR period for the initial stop. |
| `strategy_atr_sl_mult` | 3.0 | 0.1-10.0 | Initial stop distance as a multiple of ATR(20,D1). |
| `strategy_min_daily_bars` | 220 | 50-420 | Minimum D1 bars required before evaluating the monthly rule. |
| `strategy_min_bucket_obs` | 11 | 2-24 | Minimum monthly bucket observations required, including the target month. |
| `strategy_max_spread_points` | 0 | 0-100000 | Optional entry-only spread cap; 0 disables the cap for .DWX zero-spread tests. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - Direct S&P 500 backtest mapping from the card.
- `NDX.DWX` - Live-tradable US large-cap index proxy for parallel validation.
- `WS30.DWX` - Live-tradable US large-cap index proxy for parallel validation.

**Explicitly NOT for:**
- `SPX500.DWX` - Not present in the DWX symbol matrix.
- `SPY.DWX` - Not present in the DWX symbol matrix.
- `ES.DWX` - Not present in the DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` plus `QM_IsNewCalendarPeriod(PERIOD_D1)` for monthly signal refresh |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` from card frontmatter |
| Typical hold time | Monthly revalidation; positions can hold for multiple months while above the 10-month SMA |
| Expected drawdown profile | Trend-following index exposure with ATR initial stop and cash regimes below the SMA |
| Regime preference | Trend-following with turn-of-month timing |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** `blog`
**Pointer:** Alpha Architect blog, Walter Jones, "Tactical Asset Allocation: Does the Day of the Month Matter?", 2017-06-29
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12933_aa-tom-sma10-card.md`

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
| v1 | 2026-07-07 | Initial build from card | 8d7504a9-b95a-4713-be6f-c77c76403dc3 |
