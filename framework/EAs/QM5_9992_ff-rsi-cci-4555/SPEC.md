# QM5_9992_ff-rsi-cci-4555 — Strategy Spec

**EA ID:** QM5_9992
**Slug:** `ff-rsi-cci-4555`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

This EA trades the M5 ForexFactory RSI and CCI scalper. It opens long when RSI(8) crosses upward through 55 on the closed signal bar and CCI(14) is above zero, and opens short when RSI(8) crosses downward through 45 and CCI(14) is below zero. No entry is allowed while RSI remains inside the 45-55 band. Positions close on an RSI cross back through 50, a CCI cross back through zero, the fixed TP/SL, trailing management, or a 24-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 8 | 1+ | RSI period used for entry and exit thresholds. |
| `strategy_cci_period` | 14 | 1+ | CCI period used for zero-line confirmation and exit. |
| `strategy_rsi_long_level` | 55.0 | 0-100 | Long entry threshold crossed upward by RSI. |
| `strategy_rsi_short_level` | 45.0 | 0-100 | Short entry threshold crossed downward by RSI. |
| `strategy_rsi_exit_level` | 50.0 | 0-100 | RSI reverse-signal exit level. |
| `strategy_cci_zero_level` | 0.0 | any | CCI zero-line threshold for confirmation and exit. |
| `strategy_stop_pips` | 15 | 1+ | Initial hard stop distance in pips. |
| `strategy_take_profit_pips` | 15 | 1+ | Baseline take-profit distance in pips. |
| `strategy_be_trigger_pips` | 8 | 1+ | Profit in pips required before moving SL to breakeven. |
| `strategy_be_buffer_pips` | 0 | 0+ | Breakeven SL buffer in pips. |
| `strategy_trail_trigger_pips` | 12 | 1+ | Profit in pips required before step trailing starts. |
| `strategy_trail_step_pips` | 8 | 1+ | Step trailing distance in pips. |
| `strategy_time_stop_bars` | 24 | 1+ | Maximum holding time in M5 bars. |
| `strategy_session_start_utc` | 7 | 0-23 | UTC hour when entries may start. |
| `strategy_session_end_utc` | 20 | 0-23 | UTC hour when entries stop. |
| `strategy_max_spread_pips` | 1.5 | 0+ | Maximum allowed spread in pips. |
| `strategy_max_spread_stop_fraction` | 0.10 | 0-1 | Maximum spread as a fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card R3 primary FX major with direct DWX coverage.
- `GBPUSD.DWX` — card R3 primary FX major with direct DWX coverage.
- `USDJPY.DWX` — card R3 primary FX major with direct DWX coverage.
- `EURGBP.DWX` — card R3 primary FX cross with direct DWX coverage.

**Explicitly NOT for:**
- `SP500.DWX` — the card is an FX M5 scalper, not an index strategy.
- `XAUUSD.DWX` — metal volatility and spread profile are outside the card basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `220` |
| Typical hold time | `minutes to 24 M5 bars` |
| Expected drawdown profile | `scalping drawdown controlled by fixed 15-pip stop, breakeven, and trailing stop` |
| Regime preference | `liquid-session oscillator momentum continuation` |
| Win rate target (qualitative) | `medium to high` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `https://www.forexfactory.com/thread/149331-rsi-cci-system`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9992_ff-rsi-cci-4555.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-10 | Initial build from card | ae848c7c-77ac-48f6-9432-2dcb3a382b43 |
