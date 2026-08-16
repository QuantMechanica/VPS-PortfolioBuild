# QM5_20076_trendline-diagonal-break-retest - Strategy Spec

**EA ID:** QM5_20076
**Slug:** `trendline-diagonal-break-retest`
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (ForexFactory Trendline-Trader cluster)
**Author of this spec:** Claude
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

This H1 EA constructs a sloped trendline through the two most-recent confirmed
3-bar-fractal swing pivots (highs for a descending/bearish line, lows for an
ascending/bullish line), accepting the line only when the pivots are 8-80 bars
apart and the per-bar slope magnitude is at least 0.25*ATR(14). A closed bar
whose body pierces the line by at least 0.25*ATR arms a break; the EA then waits
up to 12 bars for a retest (price touches the broken line and a subsequent close
returns to the break side) and enters at the open of the bar after that
confirmation. It goes long on an upward break of a bearish line and short on a
downward break of a bullish line. Positions exit on an opposite-pivot reversal
that closes back through the broken line, a fixed RR=2.0 take-profit, or a
60-bar max-hold, whichever comes first.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fractal_k` | 3 | 2-4 | Swing-pivot fractal half-width (bars each side). |
| `strategy_min_pivot_bars` | 8 | 6-12 | Minimum bar distance between the two anchor pivots. |
| `strategy_max_pivot_bars` | 80 | 40-120 | Maximum bar distance between the two anchor pivots. |
| `strategy_atr_period` | 14 | fixed | ATR period (H1) for slope, break, and stop scaling. |
| `strategy_slope_atr_frac` | 0.25 | 0.15-0.40 | Minimum abs slope per bar as a fraction of ATR. |
| `strategy_break_atr_frac` | 0.25 | 0.15-0.40 | Close must pierce the line by this fraction of ATR. |
| `strategy_retest_bars` | 12 | 6-20 | Retest window length in bars after the break. |
| `strategy_sl_atr_mult` | 1.5 | 1.0-2.5 | ATR multiple for the volatility stop leg. |
| `strategy_struct_buffer_pts` | 5 | fixed | Buffer beyond the retest extreme for the structural stop (points). |
| `strategy_rr` | 2.0 | 1.5-3.0 | Reward:risk multiple for the take-profit. |
| `strategy_max_hold_bars` | 60 | fixed | Max-hold flatten horizon (~10 trading days). |
| `strategy_spread_cap_pts` | 25 | fixed | Spread cap in points (blocks only genuinely wide spread). |

## 3. Symbol Universe

**Designed for (registered in `magic_numbers.csv`):**
- `EURUSD.DWX` - liquid trending FX major, slot 0.
- `GBPUSD.DWX` - liquid FX major with clean diagonal channels, slot 1.
- `USDJPY.DWX` - trending FX major, slot 2.
- `AUDUSD.DWX` - commodity FX major, slot 3.
- `XAUUSD.DWX` - gold, strong diagonal-trend behaviour, slot 4.
- `NDX.DWX` - Nasdaq 100 index, clean channel trends, slot 5.
- `GDAXI.DWX` - DAX 40 index, clean channel trends, slot 6.

**Explicitly NOT for:**
- Range-bound / mean-reverting instruments where diagonal lines rarely form;
  horizontal S/R clusters are covered by the sibling horizontal-retest card.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` (framework closed-bar gate; structural state advances once per closed H1 bar) |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 18; Q02 requires at least 5/year |
| Typical hold time | intraday-to-swing, up to 60 H1 bars (~10 trading days) |
| Expected drawdown profile | approximately 18% peak; clustered losses in choppy, non-trending regimes |
| Regime preference | trending FX pairs and index CFDs that form clean diagonal channels |
| Win rate target (qualitative) | medium (RR=2.0 tolerates a sub-50% win rate) |

## 6. Source Citation

This EA was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** community forum cluster
**Pointer:** ForexFactory Trading Systems "Trendline Trader" cluster (diagonal
variant); canonical approved card at
`artifacts/cards_approved/QM5_20076_trendline-diagonal-break-retest.md`.
**R1-R4 verdict (Q00):** APPROVED. R1 lineage recorded and R2-R4 PASS per
`artifacts/cards_approved/QM5_20076_trendline-diagonal-break-retest.md`.

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
| v1 | 2026-08-11 | Initial build from card | 425526f4-c462-463b-9d30-be802d177643 |
