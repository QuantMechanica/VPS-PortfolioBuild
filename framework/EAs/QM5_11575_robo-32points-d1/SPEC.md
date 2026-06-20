# QM5_11575_robo-32points-d1 - Strategy Spec

**EA ID:** QM5_11575
**Slug:** robo-32points-d1
**Source:** e78a9f1f-4e6a-563c-a080-915133d6ed28 (see approved strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

At the first D1 bar after the prior daily candle closes, the EA reads the previous D1 close and places a two-sided pending bracket. It places a buy stop 32 pips above that close and a sell stop 32 pips below it, with a 35-pip take profit and a 28-pip stop loss on each leg. If one pending order fills, the opposite pending order is cancelled; if neither order fills within the day, pending orders are cancelled before the next D1 setup.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_entry_offset_pips | 32 | 24-40 | Distance from previous D1 close to each pending stop. |
| strategy_tp_pips | 35 | 28-45 | Take-profit distance from pending entry price. |
| strategy_sl_pips | 28 | 20-36 | Stop-loss distance from pending entry price. |
| strategy_pending_expiry_hours | 23 | 12-24 | Pending-order lifetime; daily sweep still removes stale orders. |
| strategy_friday_cutoff_hour | 21 | 0-23 | Broker-hour cutoff after which no Friday bracket is armed. |
| strategy_spread_cap_tenths_pips | 25 | 0-100 | Maximum positive spread in tenths of pips; zero .DWX modeled spread is allowed. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - The source instrument is EURUSD and the card's R3 PASS row states EURUSD.DWX is directly testable.

**Explicitly NOT for:**
- GBPUSD.DWX - Mentioned only as a possible P3 expansion candidate, not in the R3 PASS baseline basket.
- USDJPY.DWX - Mentioned only as a possible P3 expansion candidate, not in the R3 PASS baseline basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Intraday to one trading day |
| Expected drawdown profile | Fixed 28-pip risk per filled pending leg; one active position per magic. |
| Regime preference | Daily volatility-expansion breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** e78a9f1f-4e6a-563c-a080-915133d6ed28
**Source type:** book/pdf archive
**Pointer:** RoboForex strategy collection, "Strategy 32 points", page 114; local PDF `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\362359657-Robo-forex-strategy.pdf`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11575_robo-32points-d1.md`

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
| v1 | 2026-06-20 | Initial build from card | dd21fbef-8626-4445-bbdd-3eeda1f1186d |
