# QM5_10818_tv-gemini-ema - Strategy Spec

**EA ID:** QM5_10818
**Slug:** tv-gemini-ema
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView page cited in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades an EMA trend-pullback pattern on closed bars. Long entries require EMA(21) above EMA(55), the prior close at or below EMA(21) or EMA(55), the latest closed bar back above EMA(21), and RSI(14) above 50. Short entries mirror the rule with EMA(21) below EMA(55), the prior close at or above EMA(21) or EMA(55), the latest closed bar back below EMA(21), and RSI(14) below 50. Exits use a fixed 2.0R target, an initial ATR/structure stop capped at 3.0 ATR, EMA cross reversal, RSI threshold reversal, or the card's max-bars exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_fast_ema_period | 21 | 13-34 tested | Fast EMA trend and pullback period |
| strategy_slow_ema_period | 55 | 55-89 tested | Slow EMA trend period |
| strategy_rsi_period | 14 | >=1 | RSI direction and exit period |
| strategy_atr_period | 14 | >=1 | ATR stop period |
| strategy_rsi_long_threshold | 50.0 | 50-55 tested | Minimum RSI for long entries |
| strategy_rsi_short_threshold | 50.0 | 45-50 tested | Maximum RSI for short entries |
| strategy_rsi_long_exit | 45.0 | card fixed | Close long below this RSI |
| strategy_rsi_short_exit | 55.0 | card fixed | Close short above this RSI |
| strategy_atr_stop_mult | 1.5 | 1.5-2.5 tested | Initial ATR stop distance |
| strategy_atr_stop_cap_mult | 3.0 | card fixed cap | Maximum ATR stop distance |
| strategy_target_rr | 2.0 | 1.5-2.5 tested | Fixed take-profit multiple of initial risk |
| strategy_pullback_swing_bars | 5 | >=1 | Structure lookback for the pullback swing stop |
| strategy_max_h1_bars | 96 | card fixed | H1 max-bars exit |
| strategy_max_h4_bars | 60 | card fixed | H4 max-bars exit |
| strategy_session_filter_enabled | false | true/false | Optional intraday session gate from the card |
| strategy_session_start_hour | 0 | 0-23 | Broker-hour session start when enabled |
| strategy_session_end_hour | 24 | 1-24 | Broker-hour session end when enabled |
| strategy_max_spread_points | 0 | >=0 | Optional spread ceiling; 0 disables |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card R3 forex basket member with native DWX history.
- GBPUSD.DWX - card R3 forex basket member with native DWX history.
- USDJPY.DWX - card R3 forex basket member with native DWX history.
- XAUUSD.DWX - DWX matrix metal symbol corresponding to card `XAUUSD`.
- GDAXI.DWX - DWX matrix DAX symbol used for unavailable card `GER40.DWX`.
- NDX.DWX - card R3 US index basket member with native DWX history.
- WS30.DWX - card R3 US index basket member with native DWX history.

**Explicitly NOT for:**
- GER40.DWX - not present in `dwx_symbol_matrix.csv`; mapped to GDAXI.DWX.
- XAUUSD - unsuffixed symbol is not registered for backtest; mapped to XAUUSD.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | H4 setfiles also generated from the card's H1/H4 baseline statement |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Expected trade frequency | About 60 trades per year per symbol |
| Typical hold time | Up to 96 H1 bars or 60 H4 bars |
| Expected drawdown profile | Trend-pullback chop risk around EMA crosses |
| Regime preference | Trend-following |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView strategy page
**Pointer:** https://www.tradingview.com/script/uSO9nAI2-GEMINI-QUANT-PRO-Final/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10818_tv-gemini-ema.md`

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
| v1 | 2026-06-14 | Initial build from card | ca82b68c-92fd-492e-bfaf-9a9653f58b17 |
