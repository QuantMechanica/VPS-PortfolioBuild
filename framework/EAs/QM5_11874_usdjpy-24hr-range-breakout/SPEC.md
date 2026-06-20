# QM5_11874_usdjpy-24hr-range-breakout - Strategy Spec

**EA ID:** QM5_11874
**Slug:** usdjpy-24hr-range-breakout
**Source:** 92f2b500-b152-5bcc-802b-bc8fde49df4f (see local PDF archive)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

At the H1 bar whose open time maps to 6pm EST, the EA measures the high and low of the prior 24 completed H1 bars. It places a buy stop 7 pips above that high and a sell stop 7 pips below that low, with both orders expiring after 24 hours. Each order uses a 25-pip fixed stop and 50-pip fixed target. When one side becomes an open position, the EA removes the opposite pending order.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_range_hours | 24 | 1-240 | Number of completed H1 bars used to define the setup range. |
| strategy_setup_hour_utc_std | 23 | 0-23 | UTC setup hour when the United States is not in DST. |
| strategy_setup_hour_utc_dst | 22 | 0-23 | UTC setup hour when the United States is in DST. |
| strategy_breakout_offset_pips | 7 | 1-100 | Pip buffer added beyond the 24-hour range high or low. |
| strategy_sl_pips | 25 | 1-500 | Fixed stop loss distance in pips. |
| strategy_tp_pips | 50 | 1-1000 | Fixed take profit distance in pips. |
| strategy_order_expiry_hours | 24 | 1-168 | Pending order expiration window in hours. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- USDJPY.DWX - primary pair named by the card and present in the DWX matrix.
- GBPJPY.DWX - JPY cross named by the card and present in the DWX matrix.
- AUDJPY.DWX - JPY cross named by the card and present in the DWX matrix.

**Explicitly NOT for:**
- Non-JPY FX pairs - the card only approves USDJPY and JPY crosses.
- Indices, metals, and energy symbols - the source rule is a JPY forex range-breakout system.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Not specified by card; positions exit by fixed SL/TP and framework Friday close. |
| Expected drawdown profile | Fixed 25-pip stop per filled breakout order. |
| Regime preference | Breakout / volatility expansion. |
| Win rate target (qualitative) | Medium; card defines 2.0R fixed reward-to-risk. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 92f2b500-b152-5bcc-802b-bc8fde49df4f
**Source type:** local PDF archive
**Pointer:** JanusTrader, 100 Pips Daily Trading System, forexstrategiesresources.com, 2012
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11874_usdjpy-24hr-range-breakout.md`

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
| v1 | 2026-06-20 | Initial build from card | a7dedc7d-2be2-4f65-8e42-672b99f3f800 |
