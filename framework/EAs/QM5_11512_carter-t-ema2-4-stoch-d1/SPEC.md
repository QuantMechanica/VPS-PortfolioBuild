# QM5_11512_carter-t-ema2-4-stoch-d1 - Strategy Spec

**EA ID:** QM5_11512
**Slug:** carter-t-ema2-4-stoch-d1
**Source:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf (see `sources/carter-thomas-20-forex-trend-following-systems`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA trades a fast daily EMA(2) versus EMA(4) cross. A long signal occurs when EMA(2) crosses above EMA(4) on the just-closed D1 bar and Stochastic(5,3,3) %K is below 50; a short signal is the inverse cross with %K above 50. Entries are market orders on the first tick of the next D1 bar. The stop uses the prior D1 bar low for longs or high for shorts, capped at both 100 pips and 3% of entry price; take profit is 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 2 | 1-50 | Fast EMA period used for the cross trigger. |
| `strategy_ema_slow_period` | 4 | 2-100 | Slow EMA period used for the cross trigger. |
| `strategy_stoch_k` | 5 | 1-50 | Stochastic %K period. |
| `strategy_stoch_d` | 3 | 1-50 | Stochastic %D period. |
| `strategy_stoch_slowing` | 3 | 1-50 | Stochastic slowing period. |
| `strategy_stoch_threshold` | 50.0 | 0-100 | Longs require %K below this level; shorts require %K above it. |
| `strategy_sl_cap_pips` | 100 | 1-1000 | Maximum stop distance in pips. |
| `strategy_sl_cap_percent` | 3.0 | 0.1-10.0 | Maximum stop distance as percent of entry price. |
| `strategy_tp_rr` | 2.0 | 0.5-5.0 | Take-profit multiple of the final stop distance. |
| `strategy_no_friday_entry` | true | true/false | Blocks new entries on broker-time Friday. |
| `strategy_spread_cap_pips` | 30 | 1-100 | Maximum modeled spread in pips; zero DWX tester spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed DWX FX symbol with native D1 history.
- `GBPUSD.DWX` - card-listed DWX FX symbol with native D1 history.
- `USDJPY.DWX` - card-listed DWX FX symbol with native D1 history.

**Explicitly NOT for:**
- `SP500.DWX` - not part of the card's FX instrument list.
- `NDX.DWX` - not part of the card's FX instrument list.
- `WS30.DWX` - not part of the card's FX instrument list.

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
| Trades / year / symbol | 40 |
| Typical hold time | days, bounded by D1 SL/TP and Friday close |
| Expected drawdown profile | whipsaw-sensitive fast trend-following drawdowns |
| Regime preference | trend continuation |
| Win rate target (qualitative) | medium-low, offset by 2R target |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf
**Source type:** book
**Pointer:** `sources/carter-thomas-20-forex-trend-following-systems`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11512_carter-t-ema2-4-stoch-d1.md`

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
| v1 | 2026-06-26 | Initial build from card | 88e7fa8f-41bd-45e2-a118-d32ed420f778 |
