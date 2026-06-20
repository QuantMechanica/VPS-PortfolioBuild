# QM5_11521_carter-t-ema6-13-macd-psar-h4-gbp - Strategy Spec

**EA ID:** QM5_11521
**Slug:** carter-t-ema6-13-macd-psar-h4-gbp
**Source:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf (see `sources/carter-thomas-20-forex-trend-following-systems`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades H4 trend-following entries on GBP pairs when three closed-bar signals align. A long setup requires EMA(6) to have crossed above EMA(13) within the last 3 closed bars, MACD(12,26,9) main to be above zero, and Parabolic SAR(0.02,0.2) to be below the prior bar low. A short setup mirrors those rules with a bearish EMA cross, MACD below zero, and SAR above the prior bar high. Exits are handled by the source fixed stop and take-profit distance, plus the framework Friday-close guard.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_fast_period | 6 | 2-50 | Fast EMA period used for the cross trigger. |
| strategy_ema_slow_period | 13 | 3-100 | Slow EMA period used for the cross trigger. |
| strategy_macd_fast | 12 | 2-50 | MACD fast EMA period. |
| strategy_macd_slow | 26 | 3-100 | MACD slow EMA period. |
| strategy_macd_signal | 9 | 2-50 | MACD signal EMA period. |
| strategy_sar_step | 0.02 | 0.001-1.0 | Parabolic SAR acceleration step. |
| strategy_sar_max | 0.2 | 0.01-2.0 | Parabolic SAR maximum acceleration. |
| strategy_ema_cross_lookback | 3 | 1-5 | Number of closed bars in which the EMA cross may have occurred. |
| strategy_sl_pips | 40 | 1-50 | Fixed stop distance in pips for the default GBPUSD H4 build. |
| strategy_tp_rr | 2.5 | 0.5-10.0 | Take-profit distance as a multiple of stop distance. |
| strategy_no_friday_entry | true | true/false | Blocks new entries on Friday. |
| strategy_spread_cap_pips | 20 | 0-50 | Blocks entries only when modeled spread is genuinely wider than this cap. |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- GBPUSD.DWX - Source-specified GBP/USD H4 market with the default 40 pip stop and 100 pip target.
- GBPJPY.DWX - Source-specified GBP/JPY H4 market included in the card's R3 portable DWX basket.

**Explicitly NOT for:**
- Non-GBP FX symbols - The source system and card specifically name GBP/USD and GBP/JPY.
- Indices, metals, and energy symbols - The stop and signal context are from a GBP FX trend-following system, not CFD index or commodity markets.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Not specified in card frontmatter; expected to be hours to several days on H4 fixed SL/TP trades. |
| Expected drawdown profile | Trend-following whipsaw risk during sideways GBP regimes. |
| Regime preference | Trend-following / momentum continuation. |
| Win rate target (qualitative) | Medium; 2.5R target allows lower win-rate tolerance. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf
**Source type:** book
**Pointer:** Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following Systems", System #18, self-published 2014.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11521_carter-t-ema6-13-macd-psar-h4-gbp.md`.

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
| v1 | 2026-06-20 | Initial build from card | 8ad841cd-7554-42ed-9c8d-7cd14cc44fbe |
