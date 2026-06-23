# QM5_11886_floor-pivot-intraday-breakout-retest - Strategy Spec

**EA ID:** QM5_11886
**Slug:** `floor-pivot-intraday-breakout-retest`
**Source:** `202d107a-567f-5ece-b325-f3d681ee9693` (see approved strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA computes classic floor-trader pivot levels from the prior broker-day high, low, and close, then keeps those levels fixed during the next broker day. On M5, it arms a long setup when a closed bar breaks above a pivot level by at least 3 pips and then, within 6 M5 bars, retests that level from above without closing back below it. The short setup is the mirror image after a break below a level. Entries require the M5 EMA(9)/EMA(18) stack to agree with direction and the H1 MACD(12,26,9) signal line to be above zero for longs or below zero for shorts. Stop loss is 25 pips behind the broken level; take profit is the next pivot level in the trade direction; any remaining position exits at the configured trade-window end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 9 | 2-100 | Fast M5 EMA used for trend-stack confirmation. |
| `strategy_ema_slow_period` | 18 | 2-200 | Slow M5 EMA used for trend-stack confirmation. |
| `strategy_macd_fast` | 12 | 2-100 | H1 MACD fast EMA period. |
| `strategy_macd_slow` | 26 | 3-200 | H1 MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 2-100 | H1 MACD signal period. |
| `strategy_break_close_buffer_pips` | 3.0 | 0.1-50.0 | Minimum closed-bar distance beyond a pivot level to arm a breakout. |
| `strategy_retrace_touch_tol_pips` | 3.0 | 0.1-50.0 | Retest tolerance around the broken pivot level. |
| `strategy_retrace_window_bars` | 6 | 1-48 | Number of M5 bars after a breakout in which a retest may trigger. |
| `strategy_sl_pips_behind_level` | 25.0 | 1.0-250.0 | Stop-loss distance behind the broken pivot level. |
| `strategy_trade_window_start_utc` | 7 | 0-23 | UTC hour at which entries may begin. |
| `strategy_trade_window_end_utc` | 17 | 1-24 | UTC hour at which entries stop and open positions are time-stopped. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed DWX forex major with M5 data availability.
- `GBPUSD.DWX` - card-listed DWX forex major with M5 data availability.
- `USDJPY.DWX` - card-listed DWX forex major with M5 data availability.
- `USDCHF.DWX` - card-listed DWX forex major with M5 data availability.
- `USDCAD.DWX` - card-listed DWX forex major with M5 data availability.
- `AUDUSD.DWX` - card-listed DWX forex major with M5 data availability.

**Explicitly NOT for:**
- Non-DWX symbols - registry and tester runs require canonical `.DWX` symbols.
- Non-forex symbols - the approved card defines a forex pivot basket, not index, commodity, or crypto behavior.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | Prior broker-day `D1` OHLC for pivots; `H1` MACD signal line for confirmation. |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (latched once per tick in framework wiring) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday; normally minutes to hours, with hard same-session exit at 17:00 UTC. |
| Expected drawdown profile | Breakout/retest drawdowns concentrated during failed intraday pivot breaks. |
| Regime preference | Breakout / intraday volatility expansion with trend confirmation. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `202d107a-567f-5ece-b325-f3d681ee9693`
**Source type:** local PDF archive / anonymous compilation
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11886_floor-pivot-intraday-breakout-retest.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11886_floor-pivot-intraday-breakout-retest.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-23 | Initial build from card | fd346990-9c98-4a85-8011-e4e0e5f20470 |
