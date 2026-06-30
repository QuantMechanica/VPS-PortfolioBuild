# QM5_9905_ff-wmd-bop-hook-h1 - Strategy Spec

**EA ID:** QM5_9905
**Slug:** `ff-wmd-bop-hook-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9905_ff-wmd-bop-hook-h1.md`)
**Author of this spec:** Codex
**Last revised:** 2026-07-01

---

## 1. Strategy Logic

This EA trades the WMD breakout-of-price horizontal support/resistance hook pattern on closed H1 bars. It builds levels from repeated 3-left/3-right fractal swing highs or lows over the last 160 bars, waits for a decisive close through a level, and enters only when the latest closed bar retests the broken level and closes back in the breakout direction. Long trades use the retest-bar low minus an ATR buffer as the stop; shorts mirror that rule. The target is the nearest opposing level or 2.5R, whichever is closer, with an 18-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_scan_bars` | 160 | 80-240 | H1 lookback used to build repeated swing levels. |
| `strategy_fractal_left_right` | 3 | 2-5 | Bars required on both sides of a swing point. |
| `strategy_atr_period` | 14 | 10-30 | ATR period for level clustering, breakout, retest, and stop filters. |
| `strategy_touch_atr_mult` | 0.35 | 0.20-0.60 | Maximum distance between swing points in the same level cluster. |
| `strategy_break_atr_mult` | 0.25 | 0.15-0.50 | Required close beyond a level to count as a breakout. |
| `strategy_retest_atr_mult` | 0.25 | 0.15-0.50 | Maximum retest-bar distance from the broken level. |
| `strategy_retest_window_bars` | 10 | 4-16 | Maximum bars after breakout where a hook retest remains valid. |
| `strategy_min_retest_range_atr` | 0.60 | 0.30-1.00 | Minimum retest-bar range as a fraction of ATR. |
| `strategy_hook_close_fraction` | 0.35 | 0.20-0.45 | Required close location in the directional part of the retest bar. |
| `strategy_stop_buffer_atr_mult` | 0.25 | 0.10-0.50 | ATR buffer beyond the retest high/low for the hard stop. |
| `strategy_min_stop_atr_mult` | 0.50 | 0.20-1.00 | Rejects stops that are too tight. |
| `strategy_max_stop_atr_mult` | 2.40 | 1.50-3.50 | Rejects stops that are too wide. |
| `strategy_min_next_level_rr` | 2.00 | 1.00-3.00 | Required room to the next opposing level in R units. |
| `strategy_take_profit_rr` | 2.50 | 1.50-4.00 | Fallback R-multiple target when no closer opposing level exists. |
| `strategy_time_stop_bars` | 18 | 8-36 | Maximum H1 bars to hold a position. |
| `strategy_entry_start_hour` | 9 | 0-23 | Broker-time start hour for London/early-NY entries. |
| `strategy_entry_end_hour` | 20 | 1-24 | Broker-time end hour for entries. |
| `strategy_friday_last_hour` | 18 | 0-23 | Latest broker-time Friday hour allowed for new entries. |
| `strategy_max_spread_atr_fraction` | 0.15 | 0.05-0.40 | Blocks only genuinely wide spreads; zero modeled DWX spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary liquid FX major from the approved card.
- `GBPUSD.DWX` - primary liquid FX major from the approved card.
- `USDJPY.DWX` - primary liquid FX major from the approved card.
- `XAUUSD.DWX` - approved metals extension for the same level-break/retest geometry.

**Explicitly NOT for:**
- `XNGUSD.DWX` - excluded because the card is a ForexFactory FX/metals price-action setup, not a natural-gas seasonal or storage edge.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | `hours to under one day` |
| Expected drawdown profile | `Moderate trend-continuation drawdown, bounded by retest-bar structure stops.` |
| Regime preference | `breakout / support-resistance continuation` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `web_forum`
**Pointer:** `https://www.forexfactory.com/thread/206723-trading-with-deadly-accuracy`
**R1-R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9905_ff-wmd-bop-hook-h1.md`

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
| v1 | 2026-07-01 | Initial build from card | d4d83d89-ebd7-43a7-b7c1-0e6a38a6f6d6 |
