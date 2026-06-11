# QM5_11472_nekritin-peters-big-belt-d1 - Strategy Spec

**EA ID:** QM5_11472
**Slug:** nekritin-peters-big-belt-d1
**Source:** 7f773fbb-884e-54c9-a5d8-3f4087497622 (see `sources/nekritin-peters-naked-forex-wiley`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA checks each completed D1 candle for a Big Belt marubozu reversal. A bearish setup requires a gap up versus the prior close, an open in the top 20% of the candle, a close in the bottom 20%, and a fresh high versus the prior `strategy_room_bars`; it places a sell stop one pip below the candle low with the stop one pip above the high. A bullish setup mirrors the rule with a gap down, open near the low, close near the high, fresh low versus the prior room window, a buy stop one pip above the high, and a stop one pip below the low. The take profit is the nearest prior fractal-like support below a sell entry or resistance above a buy entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_room_bars` | 7 | 1+ | Prior D1 bars used for the room-to-the-left high/low test. |
| `strategy_proximity_ratio` | 0.20 | 0.01-0.49 | Maximum wick share allowed near the open/close extreme. |
| `strategy_gap_required` | true | true/false | Requires the Big Belt open to gap beyond the prior close. |
| `strategy_dow_mode` | 0 | 0-2 | Day filter: 0 any day, 1 Monday only, 2 Monday or Tuesday. |
| `strategy_pip_offset_pips` | 1.0 | >0 | Entry and stop buffer beyond the Big Belt extreme. |
| `strategy_max_range_pips` | 100 | 0+ | Skip if the Big Belt candle range exceeds this cap; 0 disables. |
| `strategy_spread_cap_pips` | 25 | 0+ | No-trade filter spread ceiling; 0 disables. |
| `strategy_fractal_lookback` | 80 | 7+ | Prior D1 bars scanned for nearest support/resistance target. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed D1 FX major with DWX data.
- `GBPUSD.DWX` - card-listed D1 FX major with DWX data.
- `USDJPY.DWX` - card-listed D1 FX major with DWX data.
- `AUDUSD.DWX` - card-listed D1 FX major with DWX data.
- `USDCAD.DWX` - card-listed D1 FX major with DWX data.

**Explicitly NOT for:**
- `SP500.DWX` - not in the card's FX instrument list.
- `NDX.DWX` - not in the card's FX instrument list.
- `WS30.DWX` - not in the card's FX instrument list.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 5 |
| Typical hold time | Not specified in card frontmatter; pending stop entries exit by nearest D1 support/resistance TP or SL. |
| Expected drawdown profile | Low-frequency, stop-defined D1 reversal losses when Big Belt extremes fail. |
| Regime preference | D1 reversal after gap-open marubozu at support/resistance zones. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 7f773fbb-884e-54c9-a5d8-3f4087497622
**Source type:** book
**Pointer:** Alex Nekritin and Walter Peters PhD, Naked Forex: High-Probability Techniques for Trading without Indicators, Chapter 9 (Wiley Trading, 2012).
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11472_nekritin-peters-big-belt-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | 6fa77974-56f2-4f98-acb3-39d0d5a5e6e5 |
