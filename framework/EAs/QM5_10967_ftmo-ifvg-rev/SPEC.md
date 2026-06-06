# QM5_10967_ftmo-ifvg-rev - Strategy Spec

**EA ID:** QM5_10967
**Slug:** `ftmo-ifvg-rev`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades failed Fair Value Gap reversals on closed M15 bars. A bearish three-candle FVG after a 20-bar downswing becomes a long signal when price trades back through the full gap and the reclaim candle closes above the upper boundary in its upper 35%. A bullish three-candle FVG after a 20-bar upswing becomes a short signal when price trades back through the full gap and the reclaim candle closes below the lower boundary in its lower 35%. The initial stop is beyond the failed FVG sequence by 0.25 ATR(14), the target is 2.0R, the stop moves to breakeven after 1.0R, and open trades close after 32 M15 bars or after a cached opposite IFVG signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 2+ | ATR period for displacement, gap-height, reclaim-range, and stop-buffer tests. |
| `strategy_swing_lookback_bars` | 20 | 2+ | Bars used to define the prior downswing or upswing before the FVG. |
| `strategy_reclaim_window_bars` | 12 | 1+ | Maximum M15 bars after FVG formation allowed for the reclaim close. |
| `strategy_time_exit_bars` | 32 | 1+ | Maximum M15 bars to hold a position before strategy exit. |
| `strategy_displacement_atr_mult` | 1.2 | 0.1+ | Minimum displacement candle body as a multiple of ATR(14). |
| `strategy_reclaim_range_atr_mult` | 0.8 | 0.1+ | Minimum reclaim candle range as a multiple of ATR(14). |
| `strategy_fvg_min_atr_mult` | 0.25 | 0.0+ | Minimum FVG height as a multiple of ATR(14). |
| `strategy_fvg_max_atr_mult` | 2.0 | 0.1+ | Maximum FVG height as a multiple of ATR(14). |
| `strategy_stop_atr_buffer_mult` | 0.25 | 0.0+ | ATR buffer beyond the failed FVG sequence high or low. |
| `strategy_tp_rr` | 2.0 | 0.1+ | Take-profit distance in R multiples. |
| `strategy_be_trigger_rr` | 1.0 | 0.1+ | Favorable move in R before moving stop to breakeven. |
| `strategy_max_spread_r_fraction` | 0.15 | 0.0-1.0 | Maximum entry spread as a fraction of initial R. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with liquid M15 OHLC suitable for IFVG reversal testing.
- `GBPUSD.DWX` - FX major with liquid M15 OHLC suitable for IFVG reversal testing.
- `XAUUSD.DWX` - liquid metal symbol with M15 displacement and reversal behavior.
- `NDX.DWX` - liquid index symbol included in the approved card's R3 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no sanctioned DWX tick data is available.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | Up to 32 M15 bars, about 8 hours. |
| Expected drawdown profile | Reversal strategy with fixed 1R stop and 2R target; drawdowns cluster during persistent trends. |
| Regime preference | Failed FVG reversal after displacement and reclaim confirmation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `blog`
**Pointer:** `https://ftmo.com/en/blog/catch-the-reversal-trading-the-inverse-fair-value-gap-ifvg-strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10967_ftmo-ifvg-rev.md`

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
| v1 | 2026-06-06 | Initial build from card | 1d44100c-8971-423b-83be-c090682cfac9 |
