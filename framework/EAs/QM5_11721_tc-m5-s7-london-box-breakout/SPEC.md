# QM5_11721_tc-m5-s7-london-box-breakout - Strategy Spec

**EA ID:** QM5_11721
**Slug:** tc-m5-s7-london-box-breakout
**Source:** 40a4454c-64ff-5015-8538-9f7b32abc0e9 (see `strategy-seeds/sources/40a4454c-64ff-5015-8538-9f7b32abc0e9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

At the 15:00 DWX broker-time session start, the EA measures the high and low of the prior 60 minutes on M5 bars. During the next hour only, it enters long when the last closed M5 candle closes above the box high plus 20% of the box height, or short when it closes below the box low minus 20% of the box height. Long stops are placed at the box low and short stops at the box high. Take profit is fixed at 4.0 times box height from the relevant box edge, and open positions trail by one box height from current price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_session_start_hour_broker` | 15 | 0-23 | DWX broker hour when the breakout session starts. |
| `strategy_signal_valid_hours` | 1 | 1-4 | Number of hours after session start when entries are valid. |
| `strategy_breakout_pct` | 0.20 | 0.01-2.00 | Fraction of box height required beyond the box edge before entry. |
| `strategy_tp_box_multiple` | 4.0 | 0.5-10.0 | Take-profit distance in box-height multiples from the box edge. |
| `strategy_trail_box_multiple` | 1.0 | 0.1-5.0 | Trailing stop distance in box-height multiples. |
| `strategy_box_minutes` | 60 | 15-240 | Length of the pre-session box window. |
| `strategy_min_box_points` | 5 | 1-1000 | Minimum valid box height in symbol points. |
| `strategy_max_spread_pips` | 8 | 1-100 | Wide-spread guard; zero modeled spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - card targets volatile GBP pairs and this symbol is present in the DWX matrix.
- `GBPUSD.DWX` - card targets volatile GBP pairs and this symbol is present in the DWX matrix.

**Explicitly NOT for:**
- Non-GBP symbols - outside the source strategy's stated volatile GBP-pair scope.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 250 |
| Typical hold time | Not specified in card; intraday by SL/TP/trailing behaviour |
| Expected drawdown profile | Not specified in card; fixed $1,000 risk per backtest trade |
| Regime preference | Volatility-expansion breakout |
| Win rate target (qualitative) | Not specified in card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 40a4454c-64ff-5015-8538-9f7b32abc0e9
**Source type:** book
**Pointer:** Thomas Carter, *20 Forex Trading Strategies (5 Minute Time Frame)*, Strategy #7; local ref `sources/tc-20-forex-strategies-m5-367145560`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11721_tc-m5-s7-london-box-breakout.md`

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
| v1 | 2026-06-20 | Initial build from card | 6f81cb83-d6b1-40c2-bb38-92ab058539bc |
