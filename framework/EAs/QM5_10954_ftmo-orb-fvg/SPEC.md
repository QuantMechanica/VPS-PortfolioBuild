# QM5_10954_ftmo-orb-fvg - Strategy Spec

**EA ID:** QM5_10954
**Slug:** ftmo-orb-fvg
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades US-session opening-range breakouts on M5 index candles. The card states its schedule in CET (15:30-15:45 opening range, 17:00 cancel, 21:00 time-exit); the tester runs in Darwinex NY-Close broker time, where the US cash open 09:30 ET maps to 16:30 year-round (broker = CET + 1h). All time anchors are therefore stored as the CET card values converted to broker time: the opening range is defined from 16:30 through 16:45 broker, then the EA waits for a closed M5 candle outside that range with a three-candle fair-value gap in the same direction. A long uses a buy-limit at the nearest bullish FVG edge (low of the most recent candle) when price is above session VWAP; a short uses a sell-limit at the nearest bearish FVG edge when price is below session VWAP. The stop is beyond the FVG middle candle and at least 0.35 times the opening-range width, the target is 2.0R, unfilled pending entries are cancelled at 18:00 broker (17:00 CET), and open positions are closed at 22:00 broker (21:00 CET).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_or_start_hhmm | 1630 | 0000-2359 | Start of opening-range window, broker HHMM (15:30 CET US cash open + 1h). |
| strategy_or_end_hhmm | 1645 | 0000-2359 | End of opening-range window / earliest breakout eval, broker (15:45 CET +1h). |
| strategy_cancel_hhmm | 1800 | 0000-2359 | Cancel unfilled FVG limit orders, broker (17:00 CET +1h). |
| strategy_time_exit_hhmm | 2200 | 0000-2359 | Close any still-open strategy position, broker (21:00 CET +1h). |
| strategy_atr_period | 14 | 2-100 | M15 ATR period used for the opening-range width filter. |
| strategy_max_or_atr_mult | 1.8 | 0.1-10.0 | Skip days where opening-range width is greater than this multiple of M15 ATR. |
| strategy_min_stop_or_mult | 0.35 | 0.01-5.0 | Minimum stop distance as a fraction of opening-range width. |
| strategy_tp_rr | 2.0 | 0.1-10.0 | Take-profit distance in R units. |
| strategy_max_spread_stop_frac | 0.08 | 0.0-1.0 | Maximum allowed spread as a fraction of stop distance. |
| strategy_session_lookback_bars | 96 | 16-288 | Bounded M5 bars copied once per new bar for OR, FVG, and VWAP state. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq 100 index CFD matches the FTMO US100 opening-session source example.
- SP500.DWX - S&P 500 custom-symbol backtest target fits the US large-cap cash-open basket.
- WS30.DWX - Dow 30 index CFD fits the same US cash-open breakout regime.

**Explicitly NOT for:**
- Forex pairs - the strategy is specified for US index CFDs at the cash open.
- Non-DWX symbols - V5 research and backtest artifacts use canonical `.DWX` symbols only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | M15 ATR(14) for opening-range width filter |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Intraday, from post-16:45-broker entry until TP, SL, or 22:00-broker time exit |
| Expected drawdown profile | Breakout losses cluster on failed US cash-open expansion days. |
| Regime preference | Volatility-expansion breakout |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** FTMO blog
**Pointer:** https://ftmo.com/en/blog/opening-range-breakout-strategy-how-to-master-the-1530-us-session/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10954_ftmo-orb-fvg.md`

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
| v1 | 2026-06-06 | Initial build from card | 81b6ff6f-51b2-45fc-88d0-508abef682a0 |
