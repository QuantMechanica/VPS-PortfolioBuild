# QM5_9467_connors-crsi-pullback-d1 — Strategy Spec

**EA ID:** QM5_9467
**Slug:** connors-crsi-pullback-d1
**Source:** ef14a5d7-e3f1-52be-910a-3ca6b736a152
**Last revised:** 2026-08-24

## 1. Strategy Logic

The EA implements the approved ConnorsRSI pullback limit-entry strategy on
closed D1 bars. A long setup requires all of the following:

- ADX(10) > 30.
- Current low <= previous close * 0.98.
- Closing range `(Close - Low) / (High - Low)` <= 0.25.
- ConnorsRSI(3,2,100) < 5.
- Spread <= 0.25 * ATR(14).

When the setup fires on bar `t`, the EA places a buy limit at `Close[t] * 0.90`,
or buys at market when the current ask is already below that limit. An unfilled
order is removed at the next governed D1 boundary, which is the end of bar
`t+1`; this is bar-based rather than a fixed 86,400-second interval. The EA
permits at most one pending order or open position for its symbol and magic.

The final protective stop is `3.0 * ATR(14)` below the actual fill. The request
is sized with that same ATR distance, and `OnTradeTransaction` rebinds the stop
to the actual position fill. If the fill-relative protection cannot be verified,
the new exposure is closed fail-closed.

An open position exits when the cached closed-bar ConnorsRSI value is above 80,
or after eight D1 bars. Exit and time-stop processing occurs before every
entry-only spread and news filter.

## 2. Parameters

| Parameter | Default | Approved test range | Meaning |
|---|---:|---:|---|
| strategy_crsi_rsi_period | 3 | 2–5 | Price RSI component period |
| strategy_crsi_streak_period | 2 | 2–5 | Streak RSI component period |
| strategy_crsi_rank_period | 100 | 50–200 | Percent-rank lookback |
| strategy_crsi_entry_thresh | 5.0 | 2.0–10.0 | Entry threshold |
| strategy_crsi_exit_thresh | 80.0 | 70.0–90.0 | Exit threshold |
| strategy_adx_period | 10 | 7–20 | ADX period |
| strategy_adx_thresh | 30.0 | 20.0–40.0 | Minimum ADX |
| strategy_closing_range_thresh | 0.25 | 0.10–0.40 | Maximum closing-range ratio |
| strategy_limit_mult | 0.90 | 0.85–0.95 | Buy-limit multiplier |
| strategy_atr_period | 14 | 7–30 | ATR period |
| strategy_sl_atr_mult | 3.0 | 1.5–5.0 | Fill-relative stop distance |
| strategy_time_stop_bars | 8 | 4–15 | Maximum D1 holding bars |
| strategy_spread_max_atr | 0.25 | 0.10–0.50 | Maximum spread / ATR ratio |
| strategy_warmup_bars | 120 | 100–200 | Minimum closed-bar history |

## 3. Symbol Universe

The approved build universe is exactly:

- `SP500.DWX` — backtest validation port.
- `NDX.DWX` — approved parallel index-CFD port.
- `WS30.DWX` — approved parallel index-CFD port.

The EA fails initialization on any other symbol. Registry allocations outside
this package are not evidence of card authorization and remain unused.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `PERIOD_D1` |
| Multi-timeframe references | None |
| Execution declaration | `QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` |
| Strategy clock | `QM_IsNewBar(_Symbol, PERIOD_D1)` |
| Indicator cadence | One immutable closed-D1 ConnorsRSI snapshot per boundary |

The card has no Friday-close rule. The framework safety close remains enabled
as an explicitly declared framework override; it does not authorize live use.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades per year per symbol | Approximately 8 |
| Typical hold time | 2–5 D1 bars, capped at 8 |
| Direction | Long only |
| Regime preference | Strong-trend pullbacks with ADX > 30 |
| Pending exposure | At most one per symbol/magic; expires after bar `t+1` |

## 6. Source Citation

**Source ID:** ef14a5d7-e3f1-52be-910a-3ca6b736a152
**Source type:** Matt Radtke / Connors Research LLC article and guidebook
**Primary URL:** https://tradingmarkets.com/recent/how-to-trade-pullbacks-u-part-3-finding-pullback-trades-1581392
**Approved card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9467_connors-crsi-pullback-d1.md`
**G0 status:** APPROVED

## 7. Risk Model

| Environment | Active mode | Inactive mode |
|---|---|---|
| Backtest | `RISK_FIXED = $1,000` | `RISK_PERCENT = 0` |
| Live setfile, if separately authorized | `RISK_PERCENT` | `RISK_FIXED = 0` |

This build and its supplied setfiles are backtest-only. It does not authorize a
live deployment, T6 action, AutoTrading change, or portfolio admission.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-22 | Initial Gemini build |
| v2 | 2026-08-24 | Review repair: card scope, D1 cadence/expiry, fill-relative stop, and clean text |
