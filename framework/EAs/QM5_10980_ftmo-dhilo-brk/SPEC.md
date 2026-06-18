# QM5_10980_ftmo-dhilo-brk - Strategy Spec

**EA ID:** QM5_10980
**Slug:** ftmo-dhilo-brk
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f (see `artifacts/cards_approved/QM5_10980_ftmo-dhilo-brk.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades closed H1 breakouts of the previous completed D1 candle high and low. A long signal requires the closed H1 candle to finish above the prior D1 high by at least 0.10 * ATR(14,H1); a short signal requires the closed H1 candle to finish below the prior D1 low by at least the same ATR buffer. The stop sits beyond the breakout candle extreme by 0.10 * ATR(14,H1), the take profit is 3.0R, the stop moves to breakeven after 1.5R, and any remaining position exits at the broker-day rollover or after 18 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 2-100 | ATR period used for H1 breakout buffer, H1 stop buffer, and D1 range filter. |
| `strategy_breakout_atr_mult` | 0.10 | 0.00-2.00 | Required H1 close distance beyond the prior D1 high or low. |
| `strategy_stop_atr_mult` | 0.10 | 0.00-2.00 | Stop buffer beyond the H1 breakout candle low or high. |
| `strategy_take_profit_rr` | 3.0 | 0.5-10.0 | Take-profit multiple of initial risk. |
| `strategy_be_trigger_rr` | 1.5 | 0.5-5.0 | Initial-risk multiple that moves SL to breakeven. |
| `strategy_max_hold_h1_bars` | 18 | 1-72 | Time stop measured in H1 bars. |
| `strategy_d1_range_min_atr` | 0.75 | 0.0-5.0 | Minimum previous-D1 range as a multiple of ATR(14,D1). |
| `strategy_d1_range_max_atr` | 2.50 | 0.1-10.0 | Maximum previous-D1 range as a multiple of ATR(14,D1). |
| `strategy_skip_monday_hours` | 2 | 0-12 | Number of early Monday broker hours to skip. |
| `strategy_skip_friday_hours` | 4 | 0-12 | Number of late Friday broker hours to skip. |
| `strategy_spread_atr_cap` | 1.00 | 0.0-5.0 | Maximum live spread as a multiple of ATR(14,H1); zero modeled spread does not block. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-approved major FX instrument with DWX history.
- `GBPUSD.DWX` - Card-approved major FX instrument with DWX history.
- `USDJPY.DWX` - Card-approved major FX instrument with DWX history.
- `XAUUSD.DWX` - Card-approved metal instrument with DWX history.

**Explicitly NOT for:**
- `SP500.DWX` - Not in the card's R3 basket for this FX/metals breakout strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | Previous completed `D1` high/low and ATR(14,D1) range filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | Same broker day, capped at 18 H1 bars |
| Expected drawdown profile | Breakout system with fixed per-trade risk and one-trade-per-day cap |
| Regime preference | Breakout / volatility expansion / trend-following |
| Win rate target (qualitative) | Low-to-medium win rate with 3.0R payoff |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** FTMO blog article
**Pointer:** FTMO, "Why do we need a structured trading plan?", 2025-06-13, https://ftmo.com/en/blog/why-do-we-need-a-structured-trading-plan/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10980_ftmo-dhilo-brk.md`

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
| v1 | 2026-06-18 | Initial build from card | 30122930-3a0a-42a3-b3bd-1ec9e6e0ec5a |
