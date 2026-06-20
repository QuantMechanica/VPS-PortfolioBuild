# QM5_9460_gh-gold-orb - Strategy Spec

**EA ID:** QM5_9460
**Slug:** gh-gold-orb
**Source:** 3b3ec48a-0755-5187-9331-afb36e174175
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades an H1 opening-range breakout. On each broker-date it records the H1 candle at the configured session-open hour, then keeps widening that range until three later H1 candles remain fully inside it. After the range is final, the first closed H1 bar that closes above the range opens a long position, and the first closed H1 bar that closes below the range opens a short position. Each session is limited to one trade, with fixed-distance SL/TP and a forced strategy close at the configured day-end hour if neither level has been hit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_session_open_hour_broker | 1 | 0-23 | Broker-server hour whose closed H1 candle defines the initial opening range. |
| strategy_session_close_hour_broker | 23 | 0-23 | Broker-server hour at or after which entries stop and open positions are closed by strategy exit. |
| strategy_consolidation_bars | 3 | >=1 | Number of subsequent H1 candles that must stay inside the current range before breakout signals are allowed. |
| strategy_stop_loss_pips | 400 | >0 | Fixed stop distance, converted through the framework pip-to-price helper for DWX scaling. |
| strategy_take_profit_pips | 1200 | >0 | Fixed take-profit distance, converted through the framework pip-to-price helper for DWX scaling. |
| strategy_max_spread_points | 0 | >=0 | Optional wide-spread block in points; 0 disables it and never blocks the DWX zero-spread tester case. |

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - Exact card target and source market for the GOLD_ORB opening-range rule.
- XAGUSD.DWX - Exact card target; same DWX metals OHLC structure as gold.
- GDAXI.DWX - Canonical DWX DAX symbol used for the card's GER40.DWX index exposure.
- WS30.DWX - Canonical DWX Dow symbol used for the card's US30.DWX index exposure.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; use GDAXI.DWX.
- US30.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; use WS30.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday, from H1 breakout until fixed TP/SL or same-day strategy close |
| Expected drawdown profile | Fixed-risk breakout drawdowns during failed range expansions and false breaks |
| Regime preference | Opening-range breakout / volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3b3ec48a-0755-5187-9331-afb36e174175
**Source type:** GitHub repository
**Pointer:** https://github.com/yulz008/GOLD_ORB, README "Strategy" and "EA Features and Inputs" sections; `GOLD_ORB/Include/price_action.mqh`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9460_gh-gold-orb.md`

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
| v1 | 2026-06-20 | Initial build from card | ed9d2527-4257-4481-9f23-9bffe1032d3b |
