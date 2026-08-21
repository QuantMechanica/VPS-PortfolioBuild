# QM5_38005_codetrading-ascending-triangle-breakout — Strategy Spec

**EA ID:** QM5_38005
**Slug:** codetrading-ascending-triangle-breakout
**Source:** codetrading-ascending-triangle-breakout-official-source (see `strategy-seeds/sources/codetrading-ascending-triangle-breakout/`)
**Author of this spec:** Gemini
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

The strategy is a systematic price action breakout system on the H1 timeframe that programmatically identifies Triangle chart patterns (Ascending and Descending Triangles) using swing pivot geometry and volume expansion. All evaluations occur strictly on closed bars (Shift = 1).

An Ascending Triangle is identified by a horizontal resistance ceiling across two swing pivot highs ($|\text{slope}| \le 0.05$) combined with ascending swing pivot lows ($L_1 > L_2$). A Long entry is triggered when Bar 1 closes above the resistance line by at least 2.0 pips and volume expands above 1.3× the 20-period volume SMA. A Descending Triangle is identified by a horizontal support floor across two swing pivot lows combined with descending swing pivot highs ($H_1 < H_2$). A Short entry is triggered when Bar 1 closes below the support line with volume expansion.

Stop Loss is placed at the most recent swing pivot extreme with a 2.0-pip buffer. Take Profit targets a 1:2.0 Risk-to-Reward ratio. Open positions move Stop Loss to Break-Even once floating profit reaches +1.0R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | `M30-H4` | Base execution and indicator timeframe |
| `strategy_pivot_window` | `4` | `3-8` | Half-window width for swing pivot identification |
| `strategy_search_bars` | `30` | `20-50` | Lookback bar search depth for triangle formation |
| `strategy_max_res_slope` | `0.05` | `0.02-0.10` | Maximum relative slope tolerance for flat boundary |
| `strategy_vol_sma_period` | `20` | `10-30` | Volume moving average baseline period |
| `strategy_vol_mult` | `1.3` | `1.0-2.0` | Minimum volume expansion multiplier over baseline |
| `strategy_atr_period` | `14` | `10-20` | ATR period for spread filtering and fallbacks |
| `strategy_sl_buffer_pips` | `2.0` | `1.0-5.0` | Pip buffer beyond swing pivot for Stop Loss |
| `strategy_tp_rr` | `2.0` | `1.0-3.0` | Risk-to-Reward multiplier for Take Profit |
| `strategy_trail_enabled` | `true` | `true/false` | Move stop loss to break-even once in profit |
| `strategy_trail_trigger_r` | `1.0` | `0.5-2.0` | Profit threshold in R-multiples to trigger BE move |
| `strategy_rollover_start_hhmm` | `2355` | `0-2359` | Start time for daily rollover blackout window |
| `strategy_rollover_end_hhmm` | `5` | `0-2359` | End time for daily rollover blackout window |
| `strategy_spread_filter_mult` | `1.8` | `1.0-3.0` | Max allowable spread as a multiple of ATR |

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
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

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
**R1–R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/approved/QM5_38005_codetrading-ascending-triangle-breakout.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | Initial build from card | Task 2f3177d2-2769-4e0d-a212-4769b908178c |
