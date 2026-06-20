# QM5_11714_chelo-gbpjpy-triple-bb50-scalp - Strategy Spec

**EA ID:** QM5_11714
**Slug:** chelo-gbpjpy-triple-bb50-scalp
**Source:** 76dfdaf4-870e-516d-80cd-a62b4f40e499
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades a GBPJPY M5 mean-reversion scalp using three Bollinger Bands with period 50 and deviations 2, 3, and 4. A short signal fires when the last closed bar closes at or above the halfway level between the upper BB(50,2) and upper BB(50,3); a long signal fires when the last closed bar closes at or below the halfway level between the lower BB(50,2) and lower BB(50,3). The EA opens at market on the next bar with a fixed 10-pip stop and fixed 7-pip take profit. Trading is limited to the card's 08:00-17:00 broker-time session and central framework news handling.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_bb_period | 50 | 2-500 | Bollinger Band and SMA basis period from the card. |
| strategy_bb_dev_inner | 2.0 | 0.1-10.0 | Inner Bollinger deviation used for the first overextension band. |
| strategy_bb_dev_middle | 3.0 | 0.1-10.0 | Middle Bollinger deviation used for the halfway trigger threshold. |
| strategy_bb_dev_outer | 4.0 | 0.1-10.0 | Outer Bollinger deviation retained as card context. |
| strategy_tp_pips | 7 | 1-100 | Fixed take-profit distance in pips. |
| strategy_sl_pips | 10 | 1-100 | Fixed stop-loss distance in pips. |
| strategy_use_session | true | true/false | Enables the broker-time session gate. |
| strategy_session_start_hr | 8 | 0-23 | Inclusive broker-time session start hour. |
| strategy_session_end_hr | 17 | 0-23 | Exclusive broker-time session end hour. |
| strategy_spread_pips | 4.0 | 0.1-50.0 | Maximum modeled spread in pips; zero spread is allowed for DWX tester data. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- GBPJPY.DWX - the approved card targets GBPJPY and R3 confirms GBPJPY.DWX M5 data availability.

**Explicitly NOT for:**
- Non-GBPJPY symbols - the source and card are GBPJPY-specific and do not provide a portable multi-symbol basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 500 |
| Typical hold time | Minutes; scalping hold bounded by 7-pip TP, 10-pip SL, and session cutoff. |
| Expected drawdown profile | Frequent small losses during extended trends away from the Bollinger mean. |
| Regime preference | Mean-revert |
| Win rate target (qualitative) | High |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 76dfdaf4-870e-516d-80cd-a62b4f40e499
**Source type:** web/PDF strategy
**Pointer:** Chelo / Rita Lasker, "Great GBPJPY 1M Scalping Strategy", ritalasker.com (180977573), local PDF reference `180977573-Forex-Gbpjpy-Scalping-Strategy.pdf`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11714_chelo-gbpjpy-triple-bb50-scalp.md`

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
| v1 | 2026-06-20 | Initial build from card | 064a87e0-9ff3-4068-b672-3a7d6b21afcb |
