# QM5_10860_tv-htf-candle - Strategy Spec

**EA ID:** QM5_10860
**Slug:** tv-htf-candle
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView source cited in card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades in the direction of the last closed higher-timeframe candle. A bullish higher-timeframe candle allows long entries and a bearish higher-timeframe candle allows short entries. Entries also require the last closed execution bar to be on the correct side of EMA(50) and to have tick volume above the SMA(20) of prior closed-bar tick volume. Positions use an ATR(14) bracket, close when the higher-timeframe bias flips, and close at end of broker day or after 480 minutes.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_htf_timeframe | PERIOD_H4 | H4-D1 | Higher timeframe used for candle open/close bias. |
| strategy_use_ema_filter | true | true/false | Enables the price-vs-EMA directional filter. |
| strategy_ema_period | 50 | 1-500 | EMA period on the execution timeframe. |
| strategy_volume_sma_period | 20 | 0-500 | Tick-volume SMA period; 0 disables the volume filter. |
| strategy_atr_period | 14 | 1-200 | ATR period used for stop and target distances. |
| strategy_atr_sl_mult | 1.5 | 0.1-10.0 | Stop distance as ATR multiple. |
| strategy_atr_tp_mult | 2.25 | 0.1-20.0 | Target distance as ATR multiple. |
| strategy_max_hold_minutes | 480 | 0-10080 | Maximum hold time; 0 disables this exit. |
| strategy_eod_flat_hour | 23 | 0-23 | Broker hour for end-of-day flat exit. |
| strategy_eod_flat_minute | 45 | 0-59 | Broker minute for end-of-day flat exit. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card R3 primary P2 forex basket member with full DWX history.
- GBPUSD.DWX - card R3 primary P2 forex basket member with full DWX history.
- USDJPY.DWX - card R3 primary P2 forex basket member with full DWX history.
- XAUUSD.DWX - card R3 primary P2 metals basket member with full DWX history.
- NDX.DWX - card R3 primary P2 index basket member with full DWX history.

**Explicitly NOT for:**
- SP500.DWX - mentioned only as later optional validation context, not part of the card's primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15, M30, H1 |
| Multi-timeframe refs | H4 or D1 candle open/close bias via strategy_htf_timeframe |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 160 |
| Typical hold time | Intraday, capped at 480 minutes or broker end-of-day |
| Expected drawdown profile | Moderate drawdown from simple HTF directional bias with ATR bracket exits |
| Regime preference | Trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source script
**Pointer:** TradingView `HTF Candle Direction Strategy V1`, author `dbkumar2026`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10860_tv-htf-candle.md`

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
| v1 | 2026-06-14 | Initial build from card | 11d7999f-f7f9-4ab0-ae24-37958e1ea332 |
