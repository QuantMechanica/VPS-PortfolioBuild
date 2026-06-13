# QM5_10445_mql5-stddev-rsi - Strategy Spec

**EA ID:** QM5_10445
**Slug:** mql5-stddev-rsi
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see MQL5 CodeBase source)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

This EA trades a mean-reversion reversal on the chart timeframe. A long setup occurs when the last closed bar opens below `SMA - 2 * StdDev`, closes back above that lower band, and RSI crosses upward through the oversold level. A short setup is the inverse: the bar opens above `SMA + 2 * StdDev`, closes back below that upper band, and RSI crosses downward through the overbought level. Stops and take-profits are placed from the market entry using fixed multiples of the same closed-bar standard deviation.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_sma_period | 20 | >= 2 | SMA period for the center line. |
| strategy_stddev_period | 20 | >= 2 | Standard deviation period for the envelope and stop distance. |
| strategy_envelope_mult | 2.0 | > 0 | Standard deviation multiplier for the entry and discretionary exit bands. |
| strategy_rsi_period | 14 | >= 2 | RSI period used for confirmation. |
| strategy_rsi_oversold | 30.0 | 0-100 | Long confirmation threshold. |
| strategy_rsi_overbought | 70.0 | 0-100 | Short confirmation threshold. |
| strategy_sl_stddev_mult | 1.0 | > 0 | Stop-loss distance in standard deviations from entry. |
| strategy_tp_stddev_mult | 2.0 | > 0 | Take-profit distance in standard deviations from entry. |
| strategy_session_start_hour | 0 | 0-23 | Broker-hour start for the optional time no-trade filter. |
| strategy_session_end_hour | 24 | 0-24 | Broker-hour end for the optional time no-trade filter. |
| strategy_max_spread_points | 20 | >= 0 | Maximum allowed current spread in points; 0 disables the spread gate. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Direct DWX analog of source EURUSD M5 target.
- GBPUSD.DWX - Direct DWX analog of source GBPUSD secondary target.

**Explicitly NOT for:**
- Non-forex index and commodity DWX symbols - The card source and R3 row name EURUSD and GBPUSD only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default skeleton gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 160 |
| Typical hold time | Not specified in frontmatter; intraday M5 mean-reversion holds are expected. |
| Expected drawdown profile | Not specified in frontmatter; controlled by StdDev stop and fixed-risk sizing. |
| Regime preference | Mean-reversion / volatility-envelope, quiet liquid FX conditions. |
| Win rate target (qualitative) | Not specified in frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** MQL5 CodeBase, "Reversal Strategy - expert for MetaTrader 5", Valentinos Konstantinou, published 2023-03-12, https://www.mql5.com/en/code/43252
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10445_mql5-stddev-rsi.md`

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
| v1 | 2026-06-13 | Initial build from card | 5f1fb432-b667-411f-9344-019a4325679e |
