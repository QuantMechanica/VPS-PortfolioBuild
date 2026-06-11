# QM5_9974_ff-bladerunner-20ema - Strategy Spec

**EA ID:** QM5_9974
**Slug:** ff-bladerunner-20ema
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see approved Strategy Card)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades the ForexFactory Bladerunner EMA20 retest pattern on M15. A long setup requires price to have closed above EMA20 on at least 3 of the last 4 closed bars, then a signal candle touches EMA20 and closes back above it, followed by a confirmation candle that closes above the signal high and above EMA20. The EA places a buy stop two pips above the confirmation high, with the stop two pips below the signal low, widened to at least 0.5 x ATR(14) when needed; shorts mirror the same logic below EMA20. Open trades target 2R, move stop to breakeven after +1R, and close early if the opposite Bladerunner setup appears.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_period | 20 | >=1 | EMA period used for trend side and retest checks. |
| strategy_trend_bars | 4 | >=1 | Number of closed bars checked for trend-side closes. |
| strategy_trend_min_side_bars | 3 | 1 to strategy_trend_bars | Minimum closes on the EMA trend side. |
| strategy_entry_offset_pips | 2.0 | >0 | Pending stop offset beyond the confirmation candle. |
| strategy_atr_period | 14 | >=1 | ATR period for minimum stop-distance enforcement. |
| strategy_min_stop_atr_mult | 0.5 | >0 | Minimum stop distance as a multiple of ATR. |
| strategy_rr_target | 2.0 | >0 | Take-profit multiple of initial risk. |
| strategy_breakeven_rr | 1.0 | >0 | Favorable move in R before moving SL to breakeven. |
| strategy_spread_max_stop_fraction | 0.08 | >0 | Maximum allowed spread as a fraction of stop distance. |
| strategy_session_filter_enabled | true | true/false | Enables London + New York liquid-session entry filter. |
| strategy_session_start_hour_broker | 7 | 0-23 | Broker-hour start of liquid-session window. |
| strategy_session_end_hour_broker | 22 | 0-24 | Broker-hour end of liquid-session window. |
| strategy_news_blackout_enabled | true | true/false | Enables card-specific high-impact news blackout hook. |
| strategy_news_before_minutes | 45 | >=0 | Minutes before high-impact news to block new trading. |
| strategy_news_after_minutes | 15 | >=0 | Minutes after high-impact news to block new trading. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX pair from the card's R3 basket.
- GBPUSD.DWX - liquid major FX pair from the card's R3 basket.
- USDJPY.DWX - liquid major FX pair from the card's R3 basket.
- XAUUSD.DWX - liquid gold CFD from the card's R3 basket.

**Explicitly NOT for:**
- SP500.DWX - index market not listed in this card's R3 basket.
- NDX.DWX - index market not listed in this card's R3 basket.
- WS30.DWX - index market not listed in this card's R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Intraday to multi-session, bounded by 2R TP, SL, opposite setup, and Friday close |
| Expected drawdown profile | Trend-pullback stops cluster during choppy EMA20 whipsaw regimes |
| Regime preference | Trend-pullback / EMA retest |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** ruben-trader, "Trading Strategy Bladerunner", ForexFactory, 2016, https://www.forexfactory.com/thread/604020-trading-strategy-bladerunner
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9974_ff-bladerunner-20ema.md`

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
| v1 | 2026-06-11 | Initial build from card | 3c790fe1-ceec-4149-a269-9e4bee2aeeb6 |
