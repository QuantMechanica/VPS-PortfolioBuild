# QM5_10616_mql5-pivotlimit - Strategy Spec

**EA ID:** QM5_10616
**Slug:** mql5-pivotlimit
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA calculates a daily pivot ladder from the previous D1 bar: S3, S2, S1, pivot, R1, R2, and R3. A long signal occurs when the prior completed intraday bar opens above a support level and touches or closes at it, then the latest completed bar closes back above that support. A short signal mirrors this at resistance: the prior bar opens below resistance and touches or closes at it, then the latest completed bar closes back below resistance. Stop loss is placed at the adjacent deeper pivot level with ATR fallback if no valid pivot stop exists, and take profit is placed by stepping the configured target variant through the pivot ladder in the profit direction.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_target_variant` | 1 | 1-5 | Number of pivot-ladder steps from the entry level to the take-profit level. |
| `strategy_touch_tolerance_points` | 2 | 0+ | Point tolerance used when deciding whether a closed bar touched a pivot level. |
| `strategy_atr_period` | 14 | 1+ | ATR period for catastrophic stop fallback when pivot levels are unusable. |
| `strategy_atr_sl_mult` | 2.0 | greater than 0 | ATR multiplier for the fallback stop. |
| `strategy_intraday_close_enabled` | true | true or false | Closes any open position at the configured broker hour. |
| `strategy_intraday_close_hour_broker` | 23 | 0-23 | Broker hour for the source `isTradeDay` intraday close behaviour. |
| `strategy_move_be_at_first_target` | true | true or false | Moves SL to entry plus spread and buffer once the nearest profit-side pivot is reached. |
| `strategy_be_buffer_points` | 2 | 0+ | Extra point buffer added to the breakeven stop move. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 lists EURUSD as a target FX major.
- `GBPUSD.DWX` - card R3 lists GBPUSD as a target FX major.
- `USDJPY.DWX` - card R3 lists USDJPY as a target FX major.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - unavailable DWX symbols cannot be registered or backtested.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | Previous D1 bar for pivot levels |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework OnTick gating |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Not specified in card frontmatter; intraday close can force flat at 23:00 broker time. |
| Expected drawdown profile | Not specified in card frontmatter; fixed-risk pivot bounce with one position per symbol and magic. |
| Regime preference | Support-resistance mean reversion around daily pivot levels. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/1054 and `artifacts/cards_approved/QM5_10616_mql5-pivotlimit.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10616_mql5-pivotlimit.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-13 | Initial build from card | ba1210e3-04de-4835-9046-b856984b3634 |
