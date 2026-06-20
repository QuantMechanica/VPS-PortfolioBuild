# QM5_11708_anon-market-squeeze-d1 - Strategy Spec

**EA ID:** QM5_11708
**Slug:** `anon-market-squeeze-d1`
**Source:** `91733bcd-fc55-59be-a119-de42fd753c3c` (see `sources/anon-scalping-forex-strategies-93933996`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades the bearish daily "market squeeze" described in the approved card. At the open of a new D1 bar, it checks whether the two prior completed days closed higher in sequence and whether the first day's close sits in the lower half of the second day's range. If so, it places a Variant A sell stop at the second day's close minus that day's full range; if that order was not filled by the following day, it can place Variant B one pip below the third day's close. Open shorts close after the first completed bearish daily candle after entry, or by SL/TP/framework exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_range_fraction` | 0.50 | 0.0-1.0 | Minimum fraction of Day 2 range above Day 1 close. |
| `strategy_sl_range_mult` | 1.50 | greater than 0 | Stop distance multiplier applied to the most recent completed daily range. |
| `strategy_fallback_pips` | 1 | greater than 0 | Variant B sell-stop offset below Day 3 close. |
| `strategy_order_valid_days` | 1 | greater than 0 | Pending sell-stop validity in calendar days. |
| `strategy_enable_variant_b` | true | true/false | Enables the card's fallback sell-stop variant. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target symbol; standard DWX D1 forex data is available.
- `GBPUSD.DWX` - card target symbol; standard DWX D1 forex data is available.
- `USDJPY.DWX` - card target symbol; standard DWX D1 forex data is available.
- `AUDUSD.DWX` - card target symbol; standard DWX D1 forex data is available.

**Explicitly NOT for:**
- Non-DWX symbols - registry and backtest tooling require `.DWX` symbols.
- Indices and commodities - the approved card's R3 row is forex-specific.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Expected trade frequency | Not specified in card frontmatter |
| Typical hold time | Not specified in card frontmatter |
| Expected drawdown profile | Not specified in card frontmatter |
| Regime preference | Multi-day price-action reversal after upward squeeze |
| Win rate target (qualitative) | Not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `91733bcd-fc55-59be-a119-de42fd753c3c`
**Source type:** anonymous self-published PDF
**Pointer:** `sources/anon-scalping-forex-strategies-93933996`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11708_anon-market-squeeze-d1.md`

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
| v1 | 2026-06-20 | Initial build from card | a6246999-9e66-4473-8efa-1d809cdcdce1 |
