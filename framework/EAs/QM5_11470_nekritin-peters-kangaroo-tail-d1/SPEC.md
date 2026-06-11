# QM5_11470_nekritin-peters-kangaroo-tail-d1 - Strategy Spec

**EA ID:** QM5_11470
**Slug:** `nekritin-peters-kangaroo-tail-d1`
**Source:** `7f773fbb-884e-54c9-a5d8-3f4087497622` (see `sources/nekritin-peters-naked-forex-wiley`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA evaluates completed D1 candles for a Kangaroo Tail / pin-bar reversal. A bullish setup requires the prior candle to have a lower shadow at least 2.0 times the body, the body in the upper half of the candle, and the low lower than the prior room-to-left window; the bearish setup mirrors those rules for the upper shadow and highs. It places a one-day buy stop above the bullish tail high or a sell stop below the bearish tail low, with the stop beyond the tail extreme and a take profit at the nearest bounded fractal support/resistance level in the trade direction.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tail_ratio` | 2.0 | greater than 0 | Minimum shadow-to-body ratio for the Kangaroo Tail. |
| `strategy_room_bars` | 7 | 1 or more | Prior D1 bars used for the room-to-left high/low test. |
| `strategy_atr_multiplier` | 0.0 | 0 or more | Optional D1 ATR(14) range filter; 0 disables it. |
| `strategy_trend_filter` | false | true or false | Enables the optional Trendy Kangaroo tail-pokes-range check. |
| `strategy_trend_bars` | 10 | 1 or more | Prior D1 bars used by the optional Trendy Kangaroo filter. |
| `strategy_entry_offset_pips` | 1 | 0 or more | Stop-entry offset beyond the signal candle high or low. |
| `strategy_stop_offset_pips` | 1 | 0 or more | Stop-loss offset beyond the tail extreme. |
| `strategy_max_stop_pips` | 100 | 1 or more | Maximum allowed entry-to-stop distance for P2. |
| `strategy_spread_cap_pips` | 25 | 0 or more | Maximum spread permitted for new entries. |
| `strategy_sr_lookback_bars` | 60 | 5 or more | Bounded D1 history window for nearest support/resistance TP scan. |
| `strategy_fractal_wing` | 2 | 1 or more | Bars on each side required to confirm a support/resistance fractal. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with D1 DWX data.
- `GBPUSD.DWX` - card-listed major FX pair with D1 DWX data.
- `USDJPY.DWX` - card-listed major FX pair with D1 DWX data.
- `AUDUSD.DWX` - card-listed major FX pair with D1 DWX data.
- `USDCAD.DWX` - card-listed major FX pair with D1 DWX data.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - no build-time registration or tester support.
- Non-FX index and commodity CFDs - the approved card specifies a D1 FX basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `10` |
| Expected trade frequency | Low frequency D1 signal cadence from the card's approval reasoning. |
| Typical hold time | Not specified in card frontmatter; pending orders expire after one D1 bar and filled trades exit by SL/TP or Friday close. |
| Expected drawdown profile | Not specified in card frontmatter; fixed $1,000 P2 risk per trade. |
| Regime preference | D1 rejection reversal at support/resistance with room to the left. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `7f773fbb-884e-54c9-a5d8-3f4087497622`
**Source type:** `book`
**Pointer:** Alex Nekritin and Walter Peters PhD, Naked Forex: High-Probability Techniques for Trading without Indicators, Chapter 8 (Wiley Trading, 2012)
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11470_nekritin-peters-kangaroo-tail-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | cefdba8c-70ab-426a-87c3-a900f8d2f62c |
