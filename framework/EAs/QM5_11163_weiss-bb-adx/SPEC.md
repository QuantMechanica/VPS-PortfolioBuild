# QM5_11163_weiss-bb-adx - Strategy Spec

**EA ID:** QM5_11163
**Slug:** weiss-bb-adx
**Source:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed D1 bars. It buys when the last closed bar pierces below a 20-period, 2-deviation Bollinger lower band while ADX(9) is below 20, and sells when the last closed bar pierces above the upper band under the same ADX nontrend condition. Entries are sent at the next bar's market price with symmetric percent take-profit and stop-loss levels from entry. There is no discretionary exit beyond broker TP/SL and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_bb_period | 20 | >= 2 | Bollinger Band lookback period. |
| strategy_bb_deviation | 2.0 | > 0 | Bollinger Band standard-deviation multiplier. |
| strategy_adx_period | 9 | >= 2 | ADX lookback period. |
| strategy_adx_max | 20.0 | > 0 | Maximum ADX allowed for entries. |
| strategy_profit_pct | 0.0125 | > 0 | Baseline symmetric TP/SL percent for non-JPY FX symbols. |
| strategy_source_parity_pct | 0.0250 | > 0 | Source-parity symmetric TP/SL percent for SP500.DWX and JPY-cross variants. |
| strategy_use_source_parity_pct | true | true/false | Enables the card's SP500.DWX and JPY-cross percent override. |
| strategy_max_spread_points | 500 | 0 disables, otherwise > 0 | Maximum current spread in points before the no-trade filter blocks entry. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX pair named in the card's P2 basket.
- EURJPY.DWX - liquid EUR/JPY cross named in the card's P2 basket.
- EURCHF.DWX - liquid EUR/CHF cross named in the card's P2 basket.
- AUDCAD.DWX - liquid AUD/CAD cross named in the card's P2 basket.
- SP500.DWX - S&P 500 custom symbol named in the card's P2 basket; valid for backtest with the card's T6 caveat.

**Explicitly NOT for:**
- Symbols outside the five registered `.DWX` rows - the EA blocks any unregistered symbol/slot combination.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 4 |
| Typical hold time | Daily signal; hold until percent TP, percent SL, or framework Friday close. |
| Expected drawdown profile | Symmetric percent stop/target creates bounded per-trade loss under V5 fixed-risk sizing. |
| Regime preference | Mean-reversion in nontrending regimes. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Source type:** book
**Pointer:** Richard L. Weissman, Mechanical Trading Systems, Chapter 4, pp. 81-82, https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11163_weiss-bb-adx.md`

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
| v1 | 2026-06-07 | Initial build from card | fd7b1b2f-307e-4a43-a257-e1fe22d3634a |
