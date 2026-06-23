# QM5_9703_ff-rsi2-scalp-m15 - Strategy Spec

**EA ID:** QM5_9703
**Slug:** `ff-rsi2-scalp-m15`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades completed M15 bars. It buys at the next bar when RSI(2, close) closes below 30, and sells at the next bar when RSI(2, close) closes above 70. Each trade uses a fixed 25-pip stop and 10-pip take-profit, rejects entries when the fixed stop is not between 0.35x and 2.5x ATR(14), moves the stop to breakeven as price advances, and exits on TP, SL, a 12-bar time stop, or an RSI midline reversal after RSI first crosses through 50 in the trade direction.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 2 | 2+ | RSI lookback on M15 closes. |
| `strategy_rsi_long_threshold` | 30.0 | 0-100 | Long entry threshold. |
| `strategy_rsi_short_threshold` | 70.0 | 0-100 | Short entry threshold. |
| `strategy_rsi_midline` | 50.0 | 0-100 | Midline used for discretionary RSI exit. |
| `strategy_atr_period` | 14 | 2+ | ATR period for spread and fixed-stop portability checks. |
| `strategy_stop_pips` | 25 | 1+ | Fixed source stop loss in symbol-normalized pips. |
| `strategy_take_pips` | 10 | 1+ | Fixed source take profit in symbol-normalized pips. |
| `strategy_be_trigger_pips` | 5 | 1+ | Profit in pips before moving stop to breakeven. |
| `strategy_be_plus_trigger_pips` | 6 | 1+ | Profit in pips before moving stop to breakeven plus buffer. |
| `strategy_be_plus_buffer_pips` | 1 | 0+ | Breakeven-plus buffer in pips. |
| `strategy_spread_atr_fraction` | 0.20 | 0+ | Maximum live spread as a fraction of ATR(14). |
| `strategy_min_stop_atr_mult` | 0.35 | 0+ | Minimum fixed-stop distance relative to ATR(14). |
| `strategy_max_stop_atr_mult` | 2.50 | 0+ | Maximum fixed-stop distance relative to ATR(14). |
| `strategy_time_stop_bars` | 12 | 1+ | Maximum holding time in M15 bars. |
| `strategy_london_start_hour` | 8 | 0-23 | Broker-hour start of the London liquid window. |
| `strategy_london_end_hour` | 12 | 0-23 | Broker-hour end of the London liquid window. |
| `strategy_newyork_start_hour` | 13 | 0-23 | Broker-hour start of the New York liquid window. |
| `strategy_newyork_end_hour` | 22 | 0-23 | Broker-hour end of the New York liquid window. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid major FX pair with native DWX data.
- `GBPUSD.DWX` - card-listed liquid major FX pair with native DWX data.
- `USDJPY.DWX` - card-listed liquid major FX pair with native DWX data.
- `XAUUSD.DWX` - card-listed liquid metal symbol with native DWX data.

**Explicitly NOT for:**
- Unregistered `.DWX` symbols - this build only reserves the four card-listed targets.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `130` |
| Typical hold time | Intraday, capped at 12 M15 bars |
| Expected drawdown profile | Scalping mean-reversion drawdowns concentrated during persistent one-way moves |
| Regime preference | Mean-reversion during London and New York liquid hours |
| Win rate target (qualitative) | High enough to support 10-pip TP versus 25-pip SL after filters |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** `https://www.forexfactory.com/thread/539300-no-long-story-rsi-system`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9703_ff-rsi2-scalp-m15.md`

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
| v1 | 2026-06-23 | Initial build from card | ffd65ff4-d92c-48f4-8653-c42b30624ca0 |
