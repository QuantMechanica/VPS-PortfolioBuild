# QM5_12791_monday-range-breakout - Strategy Spec

**EA ID:** QM5_12791
**Slug:** `monday-range-breakout`
**Source:** `sm-mining-sm007-monday-range-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

---

## 1. Strategy Logic

This EA trades a weekly FX breakout from Monday's completed D1 range. During Tuesday through Thursday broker-time H1 bars, it measures whether the last closed H1 bar broke above Monday's high plus 5 pips or below Monday's low minus 5 pips. The Monday range must be between 30 and 150 pips, each trade uses the opposite side of the Monday box plus a 10-pip stop buffer, the target is 1.5R, and the stop moves to breakeven after price moves 1R in favor. Open trades are closed by the framework Friday close, with a strategy-level Friday exit as a fallback.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_min_monday_range_pips` | 30 | 1-500 | Minimum completed Monday D1 range. |
| `strategy_max_monday_range_pips` | 150 | 1-500 | Maximum completed Monday D1 range. |
| `strategy_breakout_buffer_pips` | 5 | 1-50 | Breakout distance beyond Monday high/low. |
| `strategy_stop_buffer_pips` | 10 | 0-100 | Stop buffer beyond the opposite Monday box side. |
| `strategy_tp_r` | 1.50 | 0.25-5.00 | Take-profit as an R multiple. |
| `strategy_move_to_breakeven` | true | true/false | Move SL to entry after 1R favorable movement. |
| `strategy_entry_start_hour` | 8 | 0-23 | First broker-hour considered for closed-bar breakout. |
| `strategy_entry_end_hour` | 18 | 1-24 | Exclusive last broker-hour considered for closed-bar breakout. |
| `strategy_max_trades_per_week` | 2 | 1-5 | Maximum entry signals per Monday reference week. |
| `strategy_friday_exit_hour` | 21 | 0-23 | Strategy-level Friday exit fallback. |
| `strategy_max_spread_points` | 80 | 0-500 | Skip entry when modeled spread exceeds this many points; zero spread is allowed. |
| `strategy_d1_history_bars` | 12 | 5-20 | Bounded D1 lookup window for the latest Monday box. |

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - validated lead symbol from SM_007 and the primary portfolio-diversity target.
- `GBPUSD.DWX` - optional FX-broad port named by the card for the same weekly box-breakout calendar effect.
- `EURUSD.DWX` - optional FX-broad port named by the card for the same weekly box-breakout calendar effect.
- `AUDUSD.DWX` - optional FX-broad port named by the card for the same weekly box-breakout calendar effect.

**Explicitly NOT for:**
- `XAUUSD.DWX` - the card is an FX weekly calendar breakout, not a metal session-drift strategy.
- `XTIUSD.DWX` - commodity weekend and inventory effects are different structural drivers.
- Equity index `.DWX` symbols - the card's validation and portable basket are FX-only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `PERIOD_D1` Monday high/low range |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `33` |
| Typical hold time | `hours to several days, flat by Friday close` |
| Expected drawdown profile | `Low-frequency FX breakout drawdowns, expected DD around 12% in research prior.` |
| Regime preference | `weekly calendar range breakout / volatility expansion` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `sm-mining-sm007-monday-range-2026`
**Source type:** `OWNER campaign / local source audit`
**Pointer:** `Dropbox/FTMO March 2026/SM_Portfolio_Deploy/Experts/FTMO_SM_007_MondayRange.mq5`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12791_monday-range-breakout.md`

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
| v1 | 2026-06-29 | Initial build from card | bcf3b7cf-f0d9-475d-9199-980948c3977d |

