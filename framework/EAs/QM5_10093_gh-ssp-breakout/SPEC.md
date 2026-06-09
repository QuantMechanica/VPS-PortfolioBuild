# QM5_10093_gh-ssp-breakout - Strategy Spec

**EA ID:** QM5_10093
**Slug:** `gh-ssp-breakout`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175` (see `strategy-seeds/sources/3b3ec48a-0755-5187-9331-afb36e174175/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades a closed-bar EMA/RSI/ATR breakout on M5 or M15. A long entry requires fast EMA above slow EMA, EMA separation of at least a configured ATR fraction, the last closed bar above both EMAs, a close above the prior lookback high plus an ATR buffer, RSI inside the buy band, and a close above the prior close. A short entry mirrors those rules below the EMAs and below the prior lookback low minus the ATR buffer. Exits are fixed SL/TP points with an optional breakeven move after the configured profit trigger.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_ema_period` | 50 | 1-199 | Fast EMA period for trend direction. |
| `strategy_slow_ema_period` | 200 | 2-500 | Slow EMA period for trend direction. |
| `strategy_rsi_period` | 14 | 2-100 | RSI period for momentum band filtering. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for breakout buffer and EMA separation. |
| `strategy_breakout_lookback` | 20 | 1-500 | Closed bars used for the prior high/low breakout level. |
| `strategy_breakout_atr_buffer` | 0.50 | 0.00-5.00 | ATR multiple added to the high or subtracted from the low. |
| `strategy_ema_sep_atr_fraction` | 0.10 | 0.00-5.00 | Minimum fast/slow EMA separation as an ATR fraction. |
| `strategy_buy_rsi_min` | 40.0 | 0.0-100.0 | Lower RSI bound for long entries. |
| `strategy_buy_rsi_max` | 65.0 | 0.0-100.0 | Upper RSI bound for long entries. |
| `strategy_sell_rsi_min` | 35.0 | 0.0-100.0 | Lower RSI bound for short entries. |
| `strategy_sell_rsi_max` | 60.0 | 0.0-100.0 | Upper RSI bound for short entries. |
| `strategy_stop_points` | 150 | 1-100000 | Fixed stop-loss distance in points. |
| `strategy_take_points` | 200 | 1-100000 | Fixed take-profit distance in points. |
| `strategy_breakeven_enabled` | true | true/false | Enables breakeven stop movement. |
| `strategy_breakeven_trigger_points` | 100 | 1-100000 | Profit in points required before breakeven. |
| `strategy_breakeven_buffer_points` | 10 | 0-100000 | Points beyond entry used for breakeven stop. |
| `strategy_session_start_hour` | 0 | 0-23 | Broker-hour session start. |
| `strategy_session_end_hour` | 24 | 0-24 | Broker-hour session end. |
| `strategy_max_spread_points` | 50 | 0-100000 | Maximum spread in points; 0 disables this strategy filter. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid forex major.
- `GBPUSD.DWX` - card-listed liquid forex major.
- `XAUUSD.DWX` - card-listed metal with DWX custom-symbol coverage.
- `GDAXI.DWX` - DWX matrix equivalent for the card's DAX exposure.
- `NDX.DWX` - card-listed Nasdaq 100 index CFD.

**Explicitly NOT for:**
- `DAX.DWX` - not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is registered instead.
- Symbols outside the registered list - no implicit runtime universe expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` and `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Not specified in card frontmatter; bounded by fixed SL/TP and optional breakeven. |
| Expected drawdown profile | Fixed-risk breakout strategy; drawdown bounded by framework risk controls and stop loss. |
| Regime preference | Breakout, trend-following, momentum. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** GitHub repository
**Pointer:** `https://github.com/e49nana/Algorithmic-trading/blob/main/tradfi/mql5/SSPStrategy.mqh`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10093_gh-ssp-breakout.md`

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
| v1 | 2026-06-09 | Initial build from card | 6b92547f-e754-4210-a13b-0a209289814d |
