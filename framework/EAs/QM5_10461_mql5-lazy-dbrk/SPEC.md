# QM5_10461_mql5-lazy-dbrk - Strategy Spec

**EA ID:** QM5_10461
**Slug:** mql5-lazy-dbrk
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA reads the previous D1 bar after a new trading day begins and places a stop order above that bar's high and a stop order below that bar's low. Entry prices use the card's AddPrice offset, with the baseline set to zero pips. Unfilled pending orders are replaced at the next daily setup, and when one side fills the remaining opposite stop is cancelled. Exits are handled by the initial SL, the 2R TP, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_start_hour | 7 | 0-23 | First broker hour when the daily breakout orders may be placed. |
| strategy_end_hour | 22 | 0-23 | Broker hour when new daily setup placement stops. |
| strategy_add_price_pips | 0 | >= 0 | Offset in pips added above the prior D1 high and below the prior D1 low. |
| strategy_min_stop_pips | 5 | > 0 | Minimum stop distance from the source default Stoploss input. |
| strategy_atr_period | 14 | > 0 | ATR period on the execution timeframe for the V5 stop floor. |
| strategy_atr_sl_mult | 1.0 | > 0 | Multiplier applied to ATR(14) for the stop floor. |
| strategy_reward_risk | 2.0 | > 0 | Take-profit distance as a multiple of initial risk. |

---

## 3. Symbol Universe

**Designed for:**
- GBPUSD.DWX - direct DWX mapping of the source GBPUSD market.
- EURUSD.DWX - direct DWX mapping of the source EURUSD market.
- XAUUSD.DWX - direct DWX mapping of the source gold market.

**Explicitly NOT for:**
- Equity index `.DWX` symbols - the approved card's R3 row is FX/metals-specific.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 previous high/low; ATR on execution timeframe |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday to several days, bounded by SL/TP and Friday close |
| Expected drawdown profile | Breakout losses cluster in range-bound markets |
| Regime preference | Breakout / volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/41732
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10461_mql5-lazy-dbrk.md`

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
| v1 | 2026-05-28 | Initial build from card | 5391fbe4-e684-4986-931f-cce41083d700 |
