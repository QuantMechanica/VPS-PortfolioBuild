# QM5_11360_robo-range-wma-ema-rsi - Strategy Spec

**EA ID:** QM5_11360
**Slug:** `robo-range-wma-ema-rsi`
**Source:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades the RoboForex "The Range" M15 moving-average channel setup. A long entry fires when WMA(12) crosses above EMA(30) on the last closed bar, WMA(5) is already above both EMA(16) and EMA(30), and RSI(14) is above 50. A short entry uses the mirror condition: WMA(12) crosses below EMA(30), WMA(5) is below both EMAs, and RSI(14) is below 50. Positions close when WMA(5) crosses back through EMA(16) into the EMA channel, or when RSI(14) crosses back through 50 against the trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_wma_fast_period` | 5 | 1+ | Fast WMA used as early channel-exit and close trigger. |
| `strategy_wma_slow_period` | 12 | 1+ | Slow WMA that must cross EMA(30) to trigger entry. |
| `strategy_ema_fast_period` | 16 | 1+ | Fast EMA edge of the red range/channel. |
| `strategy_ema_slow_period` | 30 | 1+ | Slow EMA edge of the red range/channel and stop reference. |
| `strategy_rsi_period` | 14 | 1+ | RSI period used for trend confirmation and P2 close trigger. |
| `strategy_rsi_midline` | 50.0 | 0-100 | RSI threshold: above for long, below for short. |
| `strategy_stop_buffer_pips` | 5 | 1+ | Pip buffer beyond EMA(30) for the initial stop. |
| `strategy_max_stop_pips` | 20 | 1+ | Maximum allowed stop distance from entry. |
| `strategy_max_spread_pips` | 5 | 0+ | Spread cap in pips; 0 disables this strategy cap. |
| `strategy_session_start_hour` | 9 | 0-23 | Broker-hour start of the London plus NY trading window. |
| `strategy_session_end_hour` | 23 | 0-23 | Broker-hour end of the London plus NY trading window. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed liquid major FX symbol for M15 MA/RSI trend entries.
- `GBPUSD.DWX` - Card-listed liquid major FX symbol for M15 MA/RSI trend entries.
- `USDJPY.DWX` - Card-listed liquid major FX symbol for M15 MA/RSI trend entries.

**Explicitly NOT for:**
- Non-FX index and commodity `.DWX` symbols - The approved card names only EURUSD, GBPUSD, and USDJPY.
- FX symbols outside the three registered symbols - Not listed by the approved card for P2.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `200` |
| Typical hold time | Card frontmatter omits this; expected to be intraday to multi-session from M15 crossover exits. |
| Expected drawdown profile | Card frontmatter omits this; fixed 20-pip maximum SL bounds per-trade risk distance. |
| Regime preference | Trend-following / moving-average-crossover regime from card concepts and mechanics. |
| Win rate target (qualitative) | Card frontmatter omits this; no target asserted. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`
**Source type:** institutional strategy PDF
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\362359657-Robo-forex-strategy.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11360_robo-range-wma-ema-rsi.md`

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
| v1 | 2026-06-20 | Initial build from card | 509240b5-345a-4736-973f-34e28c0cdb57 |
