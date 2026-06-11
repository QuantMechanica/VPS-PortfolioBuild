# QM5_11556_carter-t-m5-ema3-8-macd-stoch-psar-sd20 - Strategy Spec

**EA ID:** QM5_11556
**Slug:** carter-t-m5-ema3-8-macd-stoch-psar-sd20
**Source:** 42530cb3-0265-534a-89cc-150f80733ff5 (see `strategy-seeds/sources/42530cb3-0265-534a-89cc-150f80733ff5/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades EURUSD on M5 when the market has at least medium Standard Deviation(20) volatility. A long signal requires EMA(3) to cross above EMA(8), Parabolic SAR to sit below the last closed bar, MACD(12,26,9) main to be above zero, and Stochastic(10,15,15) K to cross above D. A short signal uses the exact inverse, and positions close when EMA(3) crosses back through EMA(8) against the open position. Stop loss uses the recent five-bar swing, capped at 20 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_tf | PERIOD_M5 | M5 expected | Signal timeframe from the card. |
| strategy_ema_fast | 3 | >=1 | Fast EMA period. |
| strategy_ema_slow | 8 | >=1 | Slow EMA period. |
| strategy_macd_fast | 12 | >=1 | MACD fast EMA period. |
| strategy_macd_slow | 26 | >=1 | MACD slow EMA period. |
| strategy_macd_signal | 9 | >=1 | MACD signal period. |
| strategy_stoch_k | 10 | >=1 | Stochastic K period. |
| strategy_stoch_d | 15 | >=1 | Stochastic D period. |
| strategy_stoch_slowing | 15 | >=1 | Stochastic slowing period. |
| strategy_stddev_period | 20 | >=1 | Standard Deviation volatility period. |
| strategy_stddev_threshold | 0.00010 | >=0 | Medium volatility threshold for EURUSD.DWX per card notes. |
| strategy_psar_step | 0.02 | >0 | Parabolic SAR step. |
| strategy_psar_max | 0.20 | >0 | Parabolic SAR maximum. |
| strategy_sl_lookback_bars | 5 | >=1 | Swing stop lookback in closed bars. |
| strategy_sl_cap_pips | 20 | >=1 | Maximum stop distance in pips. |
| strategy_spread_cap_pips | 5 | >=0 | Blocks entries when spread exceeds this cap. |
| strategy_no_friday_entry | true | true/false | Blocks new Friday entries. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card explicitly names EURUSD.DWX and gives the non-JPY/non-AUD StdDev threshold.

**Explicitly NOT for:**
- JPY pairs - card gives different StdDev thresholds requiring symbol-specific parameterization.
- AUD/NZD pairs - card gives different StdDev thresholds requiring symbol-specific parameterization.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | intraday M5, minutes to hours |
| Expected drawdown profile | Confluence trend entries with capped fixed-pip swing risk. |
| Regime preference | medium to strong volatility trend continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 42530cb3-0265-534a-89cc-150f80733ff5
**Source type:** book
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", System #17; local card `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11556_carter-t-m5-ema3-8-macd-stoch-psar-sd20.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11556_carter-t-m5-ema3-8-macd-stoch-psar-sd20.md`

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
| v1 | 2026-06-11 | Initial build from card | 4c4a6847-3cb4-49a2-8940-20661a498415 |
