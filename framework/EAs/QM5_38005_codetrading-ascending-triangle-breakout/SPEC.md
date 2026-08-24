# QM5_38005_codetrading-ascending-triangle-breakout — Strategy Spec

**EA ID:** QM5_38005
**Slug:** codetrading-ascending-triangle-breakout
**Source:** codetrading-ascending-triangle-breakout-official-source (approved card mirror: `docs/strategy_card.md`)
**Author of this spec:** Development
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

The strategy is a systematic price action breakout system on the H1 timeframe that programmatically identifies Triangle chart patterns (Ascending and Descending Triangles) using swing pivot geometry and volume expansion. All evaluations occur strictly on closed bars (Shift = 1).

An Ascending Triangle is identified by a horizontal resistance ceiling across two swing pivot highs ($|\beta_{res}| \le 0.05$ ATR/bar) combined with an ascending support line ($\beta_{supp} \ge +0.10$ ATR/bar). A Long entry is triggered when Bar 1 closes above the time-projected resistance line by at least 2.0 pips and tick volume is strictly greater than 1.3× the 20-period volume SMA. A Descending Triangle applies the exact mirror constraints. Missing or zero mandatory volume fails closed.

Stop Loss is placed at the most recent swing pivot extreme with a 2.0-pip buffer; invalid pivot/entry geometry rejects the entry. Take Profit is the literal card target of 1.0× projected triangle height, and entry is admitted only when that target supplies at least the card's stated 1:2.0 reward:risk. At +1.0R the broker-side stop moves to entry plus/minus one tick; later completed swing pivots tighten the stop only in the profitable direction. The broker-side SL reconstructs management state after restart.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | fixed | Card execution and indicator timeframe |
| `strategy_pivot_window` | `5` | `3-10` | Half-window width for swing pivot identification |
| `strategy_search_bars` | `30` | `20-200` | Lookback bar search depth for triangle formation |
| `strategy_max_res_slope` | `0.05` | `0.02-0.10` | Maximum absolute ATR-normalized slope for flat boundary |
| `strategy_min_trend_slope` | `0.10` | `> strategy_max_res_slope` to `0.50` | Minimum ATR-normalized slope for the converging boundary |
| `strategy_vol_sma_period` | `20` | `2` to available bounded history | Volume moving average baseline period |
| `strategy_vol_mult` | `1.3` | `>1.0` | Minimum volume expansion multiplier over baseline |
| `strategy_atr_period` | `14` | `>=2` | ATR period for spread filtering and slope normalization |
| `strategy_sl_buffer_pips` | `2.0` | `1.0-5.0` | Pip buffer beyond swing pivot for Stop Loss |
| `strategy_triangle_height_mult` | `1.0` | fixed | Triangle-height target multiplier |
| `strategy_tp_rr` | `2.0` | fixed | Minimum R:R required from the height target |
| `strategy_trail_enabled` | `true` | fixed | Enable break-even then swing-pivot trailing |
| `strategy_trail_trigger_r` | `1.0` | fixed | Profit threshold in R-multiples to enter protected state |
| `strategy_rollover_start_hhmm` | `2355` | `0-2359` | Start time for daily rollover blackout window |
| `strategy_rollover_end_hhmm` | `5` | `0-2359` | End time for daily rollover blackout window |
| `strategy_spread_filter_mult` | `1.8` | `1.0-3.0` | Max allowable spread as a multiple of ATR |
| `strategy_max_slippage_ticks` | `3` | `1-3` | Market-order deviation ceiling in native ticks |
| `strategy_daily_loss_halt_pct` | `2.0` | `0-2.0` | Realized daily loss entry halt |
| `strategy_daily_hard_stop_pct` | `2.5` | `0-2.5` | Framework daily equity hard stop |
| `strategy_total_dd_halt_pct` | `5.0` | `0-5.0` | Framework portfolio drawdown signal threshold |
| `strategy_per_trade_risk_cap_pct` | `0.5` | `0-0.5` | Live percent-mode per-trade risk cap |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — Primary high-volatility commodity asset with strong structural consolidation-breakout characteristics
- `SP500.DWX` — Liquid equity benchmark with clear institutional consolidation patterns
- `EURUSD.DWX` — Major FX pair with well-defined horizontal support/resistance levels

**Explicitly NOT for:**
- Illiquid exotic currency pairs or choppy low-volume ranges without momentum expansion

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `PERIOD_H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_signal_tf)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | 4 to 36 hours |
| Expected drawdown profile | Low, < 4% Max Drawdown |
| Regime preference | Structural Consolidation to Expansion / Breakout |
| Win rate target (qualitative) | High (65-75%) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `codetrading-ascending-triangle-breakout-official-source`
**Source type:** `video`
**Pointer:** `CodeTrading (2022). How to Detect and Trade Triangle Patterns in Python. YouTube.`
**R1–R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_38005_codetrading-ascending-triangle-breakout.md` and the content-equivalent local mirror `docs/strategy_card.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit`; backtest setfiles retain `RISK_FIXED=1000` and `RISK_PERCENT=0`. Live percent sizing is additionally capped at 0.50% through the framework risk sizer.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | Initial build from card | Task 2f3177d2-2769-4e0d-a212-4769b908178c |
| v2 | 2026-08-24 | Review rework | Task d840a938-f474-48fe-bf94-ce7cb82a8f17; fixes slopes, volume, target/trailing, capital controls, UTC and startup ordering |
| v3 | 2026-08-24 | Burn-window build completion | Ticket build-QM5_38005_codetrading-ascending-triangle-breakout; approved-card mirror and governed artifacts refreshed |
