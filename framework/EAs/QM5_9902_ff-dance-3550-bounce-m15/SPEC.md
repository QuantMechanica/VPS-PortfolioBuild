# QM5_9902_ff-dance-3550-bounce-m15 - Strategy Spec

**EA ID:** QM5_9902
**Slug:** ff-dance-3550-bounce-m15
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see ForexFactory Trading Systems source collection)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades the ForexFactory Dance 35/50 cluster bounce on completed M15 bars. It looks for a bullish or bearish moving-average stack, requires SMA35 and EMA50 to be tightly clustered, then waits for a pullback bar to touch that cluster and a following closed bar to confirm back through EMA10. It enters at market on the next M15 bar, sets the stop beyond the pullback swing by an ATR buffer, takes profit at 1.6R, and exits early if price or EMA10 closes through the 35/50 cluster against the trade or if 32 M15 bars have elapsed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_timeframe | PERIOD_M15 | M1-MN1 | Signal timeframe from the card. |
| strategy_ema_fast_period | 10 | >=1 | Fast EMA used for stack and confirmation. |
| strategy_sma_cluster_period | 35 | >=1 | SMA side of the 35/50 support/resistance cluster. |
| strategy_ema_cluster_period | 50 | >=1 | EMA side of the 35/50 support/resistance cluster. |
| strategy_ema_trend_period | 100 | >=1 | Trend EMA used for stack and slope. |
| strategy_atr_period | 14 | >=1 | ATR period used for cluster tightness, spread, and stop checks. |
| strategy_trend_slope_bars | 12 | >=1 | EMA100 slope lookback in bars. |
| strategy_cluster_tight_atr_mult | 0.25 | >0 | Maximum allowed SMA35 to EMA50 distance in ATR units. |
| strategy_pullback_touch_atr_mult | 0.10 | >=0 | Pullback touch tolerance around the cluster in ATR units. |
| strategy_stop_buffer_atr_mult | 0.25 | >0 | Stop buffer beyond the pullback swing in ATR units. |
| strategy_min_stop_atr_mult | 0.45 | >0 | Minimum allowed stop distance in ATR units. |
| strategy_max_stop_atr_mult | 2.20 | >0 | Maximum allowed stop distance in ATR units. |
| strategy_take_profit_rr | 1.60 | >0 | Fixed reward/risk target. |
| strategy_max_hold_bars | 32 | >=1 | Time stop in M15 bars. |
| strategy_min_spacing_bars | 8 | >=1 | Minimum spacing between same-direction entries. |
| strategy_session_start_hour_broker | 8 | 0-23 | Broker-hour start for Frankfurt/London trading. |
| strategy_session_end_hour_broker | 17 | 0-24 | Broker-hour end after early New York trading. |
| strategy_max_spread_atr_pct | 12.0 | >=0 | Maximum spread as a percent of ATR14. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Primary liquid DWX major pair named in the card's R3 basket.
- GBPUSD.DWX - Liquid London-session DWX major pair named in the card's R3 basket.
- USDJPY.DWX - Liquid DWX major pair named in the card's R3 basket.
- EURJPY.DWX - Liquid DWX JPY cross named in the card's R3 basket.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research and backtest artifacts require canonical `.DWX` symbols.
- Symbols outside `dwx_symbol_matrix.csv` - the broker/test terminals have no sanctioned data for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 95 |
| Typical hold time | Intraday, capped at 32 M15 bars |
| Expected drawdown profile | Pullback trend-following drawdowns during choppy non-trending sessions |
| Regime preference | Trend-pullback / intraday mean-reversion into MA support-resistance |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/460041-the-dance-continues
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9902_ff-dance-3550-bounce-m15.md`

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
| v1 | 2026-06-11 | Initial build from card | 92339123-28d4-4320-bd63-86d7e3b47792 |
