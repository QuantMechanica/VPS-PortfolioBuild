# QM5_9952_ff-zigzag-trendline-4060-m5 - Strategy Spec

**EA ID:** QM5_9952
**Slug:** `ff-zigzag-trendline-4060-m5`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades M5 reversals after a confirmed ZigZag swing is large enough: at least 100 pips on XAUUSD.DWX, or at least 2.5 x ATR(14) on the FX symbols. After a downward swing from a pivot high to a pivot low, it fits a least-squares line through the latest 14 M5 closes after the pivot low and buys when the last closed M5 high breaches that descending line by 0.10 x ATR(14). The short side mirrors the rule after an upward swing, using a rising least-squares line and a last-closed-bar low breach. Exits are the fixed 40-pip stop, fixed 60-pip target, break-even at +40 pips, the framework Friday close, or a 36 M5-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_M5` | M5 expected | Signal timeframe from the card. |
| `strategy_zigzag_depth` | `12` | `2-100` | Local pivot depth for confirmed swing detection. |
| `strategy_zigzag_deviation_pips` | `5` | `1-100` | Minimum move between alternating pivots. |
| `strategy_zigzag_backstep` | `3` | `1-50` | Same-side pivot replacement window. |
| `strategy_zigzag_scan_bars` | `240` | `60-1000` | Closed-bar window used to find the latest ZigZag swing. |
| `strategy_trendline_lookback` | `14` | `3-100` | Number of closes used for the least-squares trigger line. |
| `strategy_trendline_projection_bars` | `10` | `0-50` | Card projection parameter retained for traceability; entry compares the current edge of the fitted line. |
| `strategy_atr_period` | `14` | `2-100` | ATR period for swing normalization and breach distance. |
| `strategy_breach_atr_mult` | `0.10` | `0.01-2.0` | Required breach beyond the fitted line. |
| `strategy_xau_swing_min_pips` | `100` | `10-1000` | Minimum XAUUSD swing size. |
| `strategy_fx_swing_atr_mult` | `2.50` | `0.5-10.0` | Minimum FX swing size as ATR multiple. |
| `strategy_sl_pips` | `40` | `1-500` | Fixed source stop. |
| `strategy_tp_pips` | `60` | `1-1000` | Fixed source target. |
| `strategy_sl_atr_fallback_mult` | `1.25` | `0.1-10.0` | ATR fallback if fixed-pip distance cannot be formed. |
| `strategy_be_trigger_pips` | `40` | `1-500` | Break-even trigger. |
| `strategy_be_buffer_pips` | `0` | `0-100` | Break-even buffer. |
| `strategy_time_stop_bars` | `36` | `1-500` | Maximum hold in M5 bars. |
| `strategy_session_start_hour` | `7` | `0-23` | Broker-hour session start. |
| `strategy_session_end_hour` | `18` | `1-24` | Broker-hour session end, exclusive. |
| `strategy_max_spread_points` | `0` | `0+` | Optional spread cap; `0` disables the cap. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - source market and primary P2 symbol for M5 gold ZigZag swings.
- `EURUSD.DWX` - DWX FX major with ATR-normalized swing threshold.
- `GBPUSD.DWX` - DWX FX major with ATR-normalized swing threshold.
- `USDJPY.DWX` - DWX FX major with ATR-normalized swing threshold.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 pipeline requires `.DWX` research/backtest symbols.
- Equity indices and sector ETFs - this card's R3 basket is XAU plus FX majors, not an index basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_signal_tf)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | Up to 36 M5 bars, about 3 hours unless SL/TP/BE fires earlier. |
| Expected drawdown profile | Fixed-stop breakout/reversal profile; losses cluster when large swings continue without a trendline reversal. |
| Regime preference | M5 post-swing trendline reversal / volatility expansion. |
| Win rate target (qualitative) | Medium; source uses 40-pip stop and 60-pip target. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** jamesagnew, "40-60 rule, Trader using trendline secret method", ForexFactory, 2025, https://www.forexfactory.com/thread/post/15198046
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9952_ff-zigzag-trendline-4060-m5.md`

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
| v1 | 2026-06-11 | Initial build from card | d35eeb45-6e75-41d8-8549-58dc8afdd262 |
