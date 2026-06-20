# QM5_11506_carter-t-ema10-25-50-psar-m30 - Strategy Spec

**EA ID:** QM5_11506
**Slug:** carter-t-ema10-25-50-psar-m30
**Source:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades a three-EMA trend alignment on M30. A long entry is allowed when EMA(10) is above EMA(25), EMA(25) is above EMA(50), the last closed bar closes above EMA(10), and Parabolic SAR(0.02, 0.20) is below that closed bar's low. A short entry mirrors the same rule with the EMA stack bearish, the close below EMA(10), and SAR above the closed bar's high. The stop is the current SAR dot at entry capped to 30 pips, and take profit is 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_fast_period | 10 | 1-200 | Fast EMA in the ribbon. |
| strategy_ema_mid_period | 25 | 1-300 | Middle EMA in the ribbon. |
| strategy_ema_slow_period | 50 | 1-500 | Slow EMA in the ribbon. |
| strategy_sar_step | 0.02 | 0.001-0.20 | Parabolic SAR acceleration step. |
| strategy_sar_max | 0.20 | 0.01-1.00 | Parabolic SAR maximum acceleration. |
| strategy_spread_cap_pips | 15 | 0-100 | Entry is blocked only when modeled spread is wider than this pip cap. |
| strategy_sl_cap_pips | 30 | 1-300 | Maximum stop distance from entry when the SAR dot is farther away. |
| strategy_take_profit_rr | 2.0 | 0.1-10.0 | Take-profit multiple of stop distance. |
| strategy_no_friday_entry | true | true/false | Suppresses new entries on broker-time Friday. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed M30 DWX FX instrument.
- GBPUSD.DWX - Card-listed M30 DWX FX instrument.
- AUDUSD.DWX - Card-listed M30 DWX FX instrument.

**Explicitly NOT for:**
- Non-DWX symbols - the build and pipeline require Darwinex `.DWX` history and magic registry rows.
- Indices, metals, and energy CFDs - not listed in the card's R3 portable basket for this strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday to multi-session, bounded by SL/TP and Friday close |
| Expected drawdown profile | Trend-following drawdowns during sideways FX regimes |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf
**Source type:** book
**Pointer:** Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following Systems", System #1, self-published 2014.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11506_carter-t-ema10-25-50-psar-m30.md`

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
| v1 | 2026-06-20 | Initial build from card | 30281dbe-1949-497b-a409-66ee2c821a39 |
