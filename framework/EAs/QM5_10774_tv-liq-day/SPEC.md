# QM5_10774_tv-liq-day - Strategy Spec

**EA ID:** QM5_10774
**Slug:** tv-liq-day
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-01

---

## 1. Strategy Logic

The EA computes the previous daily high and previous daily low from D1 bars, then evaluates closed M15 bars during the enabled London and New York sessions. It enters long when the last closed M15 bar closes above the prior daily high, and enters short when the last closed M15 bar closes below the prior daily low. It allows only one long breakout and one short breakout per trading day, uses fixed percentage SL/TP brackets, and closes any remaining intraday position after the New York session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_london_enabled | true | true/false | Enables the London session entry window. |
| strategy_london_start_hour | 8 | 0-23 | Broker-time hour when the London session window starts. |
| strategy_london_end_hour | 17 | 0-23 | Broker-time hour when the London session window ends. |
| strategy_newyork_enabled | true | true/false | Enables the New York session entry window and end-of-day close. |
| strategy_newyork_start_hour | 14 | 0-23 | Broker-time hour when the New York session window starts. |
| strategy_newyork_end_hour | 22 | 0-23 | Broker-time hour when the New York session window ends. |
| strategy_stop_percent | 0.50 | > 0 | Stop distance as a percentage of entry price. |
| strategy_target_percent | 1.00 | > 0 | Target distance as a percentage of entry price. |
| strategy_atr_period | 14 | >= 1 | ATR period used only when a percentage stop is below broker stop distance. |
| strategy_min_atr_gate_enabled | false | true/false | Optional ATR activity filter from the card. |
| strategy_min_atr_points | 0.0 | >= 0 | Minimum ATR in points when the optional ATR gate is enabled. |
| strategy_max_spread_points | 50 | >= 0 | Maximum allowed spread in points before new entries are blocked. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX pair from the card's R3 basket.
- GBPUSD.DWX - liquid major FX pair from the card's R3 basket.
- USDJPY.DWX - liquid major FX pair from the card's R3 basket.
- XAUUSD.DWX - gold CFD from the card's R3 basket.
- GDAXI.DWX - canonical DWX DAX symbol, used for the card's GER40.DWX DAX exposure.
- NDX.DWX - Nasdaq 100 CFD from the card's R3 basket.
- WS30.DWX - Dow 30 CFD from the card's R3 basket.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX equivalent.
- XAUUSD - unsuffixed research shorthand only; backtest registry uses XAUUSD.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | D1 previous-day high and low |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Intraday, normally closed by SL/TP or New York session end |
| Expected drawdown profile | False breakouts around prior-day extremes are the main loss mode. |
| Regime preference | Breakout / volatility expansion during active sessions |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `Liquidity Day Strategy V1`, author handle `GodeyeThelasthope`, Feb 14, https://www.tradingview.com/script/1XWV0QW3-Liquidity-Day-Strategy-V1/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10774_tv-liq-day.md`

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
| v1 | 2026-06-01 | Initial build from card | 615e0d54-bbf6-4045-b48d-a03dd26e8fc5 |
