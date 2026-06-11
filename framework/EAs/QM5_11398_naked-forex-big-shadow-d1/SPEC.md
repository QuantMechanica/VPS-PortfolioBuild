# QM5_11398_naked-forex-big-shadow-d1 - Strategy Spec

**EA ID:** QM5_11398
**Slug:** naked-forex-big-shadow-d1
**Source:** 94a3a139-a123-57c2-ae40-b5513532e244 (see `strategy-seeds/sources/94a3a139-a123-57c2-ae40-b5513532e244/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades the Naked Forex Big Shadow reversal pattern on completed D1 bars. A sell setup requires the latest closed candle to extend above the prior candle, be more than twice the prior range, be at least 1.2 times every prior range in the 20-bar lookback, close in its bottom third, and set a fresh 20-bar high. A buy setup mirrors the rule at lows: the latest closed candle extends below the prior candle, is the largest relative candle in the lookback, closes in its top third, and sets a fresh 20-bar low. Entries are pending stop orders beyond the Big Shadow candle by 5 pips, with TP at 2.5 x ATR(14), the stop beyond the candle extreme plus 5 pips subject to the 80-pip P2 cap, and break-even management after 1 x ATR favourable movement.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_bars` | 20 | >= 1 | Lookback for largest-range and fresh high/low checks. |
| `strategy_range_mult` | 2.0 | > 0 | Minimum ratio of the Big Shadow range to the immediately prior candle range. |
| `strategy_largest_mult` | 1.2 | > 0 | Minimum ratio of the Big Shadow range to each candle range in the lookback. |
| `strategy_entry_buffer_pips` | 5.0 | > 0 | Pending stop offset beyond the Big Shadow high or low. |
| `strategy_atr_period` | 14 | >= 1 | ATR period for TP and break-even trigger. |
| `strategy_tp_atr_mult` | 2.5 | > 0 | Take-profit distance in ATR multiples from entry. |
| `strategy_be_atr_mult` | 1.0 | >= 0 | Favourable movement in ATR multiples before moving SL to break-even. |
| `strategy_max_sl_pips` | 80.0 | > 0 | P2 maximum stop distance in pips. |
| `strategy_spread_cap_pips` | 25.0 | > 0 | Maximum allowed spread in pips before entries are blocked. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed DWX FX major.
- `GBPUSD.DWX` - card-listed DWX FX major.
- `USDJPY.DWX` - card-listed DWX FX major.
- `AUDUSD.DWX` - card-listed DWX FX major.
- `USDCAD.DWX` - card-listed DWX FX major.

**Explicitly NOT for:**
- Equity index `.DWX` symbols - the card specifies D1 DWX FX only.
- Metals and energy `.DWX` symbols - the card specifies major currency pairs only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | multi-day D1 swing; not explicitly stated in card frontmatter |
| Expected drawdown profile | fixed-risk reversal entries with wide D1 stops capped at 80 pips |
| Regime preference | momentum-exhaustion reversal at 20-bar extremes |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 94a3a139-a123-57c2-ae40-b5513532e244
**Source type:** book
**Pointer:** Alex Nekritin & Walter Peters, Naked Forex, Wiley 2012, Chapter 6: The Big Shadow; local PDF `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\531226675-Naked-Forex.pdf`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11398_naked-forex-big-shadow-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | 872e6673-42c3-45d6-a114-27f457e29a2b |
