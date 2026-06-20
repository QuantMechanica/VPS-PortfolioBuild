# QM5_11529_ciurea-hammer-hanging-man-m15 - Strategy Spec

**EA ID:** QM5_11529
**Slug:** ciurea-hammer-hanging-man-m15
**Source:** 0192e348-5570-531c-9110-7954a36caca2
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA evaluates the last closed M15 candle for Ciurea's Hammer / Hanging Man shape. The candle must have a body larger than 3 pips, a lower shadow at least 2.0 times the body, and an upper shadow no larger than 0.5 times the body. It enters at the next bar through a market order in the configured direction, places the stop 3 pips beyond the last 3 closed bars' low or high, rejects signals whose stop is wider than 20 pips, and sets the take profit at 2R. There is no discretionary exit beyond SL, TP, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_side | 1 | -1 or 1 | Selects the card variant: 1 trades Hammer long, -1 trades Hanging Man short. |
| strategy_body_min_pips | 3 | 1-20 | Minimum candle body size in pips. |
| strategy_lower_shadow_mult | 2.0 | 0.5-5.0 | Lower shadow must be at least this multiple of the body. |
| strategy_upper_shadow_mult | 0.5 | 0.0-2.0 | Upper shadow must be no more than this multiple of the body. |
| strategy_stop_lookback | 3 | 1-10 | Number of closed M15 bars used for the structural stop extreme. |
| strategy_stop_buffer_pips | 3 | 1-20 | Pip buffer beyond the 3-bar low or high. |
| strategy_stop_cap_pips | 20 | 1-100 | Maximum allowed stop distance for P2. |
| strategy_reward_risk | 2.0 | 0.5-5.0 | Take-profit multiple of initial risk. |
| strategy_spread_cap_pips | 12 | 1-50 | Maximum modeled spread allowed for entry; zero-spread DWX quotes are allowed. |
| strategy_no_friday_entry | true | true or false | Blocks new Friday entries per card. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Source-specified M15 pair with the strongest cited trade count.
- GBPUSD.DWX - Card approval text identifies GBPUSD DWX as testable FX exposure from the same source family.

**Explicitly NOT for:**
- Non-FX index, metals, energy, and crypto `.DWX` symbols - The approved card only cites FX candle-pattern evidence.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 313 on EURUSD M15 per source sample |
| Expected trade frequency | Frequent intraday candle-pattern entries |
| Typical hold time | Not specified in card; bounded by 2R target, structural SL, and Friday close |
| Expected drawdown profile | Low win-rate reversal profile with many small fixed-risk outcomes |
| Regime preference | Candlestick reversal / price action |
| Win rate target (qualitative) | Low to medium; source EURUSD M15 win rate was 33.68% |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0192e348-5570-531c-9110-7954a36caca2
**Source type:** Self-published trading article / PDF
**Pointer:** Cristina Ciurea, "The Truth Behind Commonly Used Indicators", ScientificForex.com, approximately 2012
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11529_ciurea-hammer-hanging-man-m15.md`

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
| v1 | 2026-06-20 | Initial build from card | e6e3545a-1436-474e-bd11-34da55896501 |
