# QM5_10735_tv-hilo-atr - Strategy Spec

**EA ID:** QM5_10735
**Slug:** tv-hilo-atr
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA records the high and low of the first 30 minutes of the configured broker-chart session. After that range is locked, it buys when a closed M5 bar closes above the range high and sells when a closed M5 bar closes below the range low. The initial stop is the wider of 1% from entry and ATR(14) times 3.5, with a full-position target at 3% from entry. Open positions trail by ATR(14) times 3.5 and are force-closed at 15:15 broker/chart time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_allow_long | true | true/false | Enables long breakouts above the opening range high. |
| strategy_allow_short | true | true/false | Enables short breakouts below the opening range low. |
| strategy_or_start_hhmm | 930 | 0000-2359 | Broker/chart session time when the opening range starts. |
| strategy_or_minutes | 30 | >0 | Number of minutes used to build the opening high/low range. |
| strategy_force_flat_hhmm | 1515 | 0000-2359 | Broker/chart session time for forced strategy close. |
| strategy_atr_period | 14 | >0 | ATR lookback used for initial and trailing stops. |
| strategy_atr_mult | 3.5 | >0 | ATR multiplier used for initial and trailing stops. |
| strategy_fixed_stop_pct | 1.0 | >0 | Percent stop distance candidate from entry. |
| strategy_target_pct | 3.0 | >0 | Full-position target distance from entry. |
| strategy_min_or_points | 10 | >=0 | Minimum opening-range width in points. |
| strategy_max_spread_points | 0 | >=0 | Optional spread block; 0 disables the spread cap. |
| strategy_max_trades_day | 2 | 1-2 | Maximum daily signals, allowing one re-entry after a losing first trade. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - DWX Nasdaq 100 index exposure fits the TradingView high/low breakout concept.
- WS30.DWX - DWX Dow 30 index exposure fits the same intraday opening-range breakout structure.
- XAUUSD.DWX - DWX gold exposure is listed in the approved R3 basket and supports ATR/session testing.
- EURUSD.DWX - DWX major FX exposure is listed in the approved R3 basket and supports OHLC/ATR testing.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest artifacts must use canonical DWX symbols from the matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Intraday, from post-opening-range breakout until target, ATR trail, or 15:15 flat time. |
| Expected drawdown profile | Breakout system with loss clusters on false breaks and narrow/no-breakout days skipped. |
| Regime preference | Opening-range breakout / volatility expansion. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source script
**Pointer:** https://www.tradingview.com/script/UPuf4zqJ-High-Low-Breakout-Strategy-with-ATR-traling-Stop-Loss/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10735_tv-hilo-atr.md`

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
| v1 | 2026-06-14 | Initial build from card | f67503e7-d85a-4492-9e98-c6578716f5b4 |
