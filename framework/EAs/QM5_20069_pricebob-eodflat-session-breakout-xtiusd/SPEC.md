# QM5_20069_pricebob-eodflat-session-breakout-xtiusd — Strategy Spec

**EA ID:** QM5_20069
**Slug:** `pricebob-eodflat-session-breakout-xtiusd`
**Source:** `68eff294-e3b2-5010-82d8-e9dd5f4130e6` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-07-31

---

## 1. Strategy Logic

At the close of each trading day's 13:30 broker-time M15 bar, the EA stores that bar's high and low as the reference range. It enters once that day at market when a later M15 bar closes above the reference high or below the reference low, provided the reference range is between 0.3 and 2.5 times the prior closed D1 ATR(14) and the positive spread is no more than 20% of the range. The stop is the opposite reference edge, the target is one reference range from entry, and any remaining position is closed at 21:00 broker time with no break-even or trailing logic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_reference_hour_broker` | 13 | 0–23 | Broker-time hour of the M15 reference bar. |
| `strategy_reference_minute_broker` | 30 | 0–59 | Broker-time minute of the M15 reference bar. |
| `strategy_session_close_hour_broker` | 21 | 0–23 | Broker-time hour for mandatory same-day flattening. |
| `strategy_session_close_minute_broker` | 0 | 0–59 | Broker-time minute for mandatory same-day flattening. |
| `strategy_daily_atr_period` | 14 | ≥2 | Closed-D1 ATR period used by the reference-range gate. |
| `strategy_ref_range_min_atr_ratio` | 0.30 | ≥0 | Minimum reference range as a fraction of D1 ATR. |
| `strategy_ref_range_max_atr_ratio` | 2.50 | > minimum ratio | Maximum reference range as a fraction of D1 ATR. |
| `strategy_max_spread_ref_range_ratio` | 0.20 | ≥0 | Maximum positive spread as a fraction of reference range. |
| `strategy_target_ref_range_mult` | 1.00 | >0 | Take-profit distance in reference-range multiples. |

> Framework-level risk, news, Friday-close, stress and seed inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — the approved WTI commodity CFD port with an intraday NY-session liquidity structure and no overnight holding.

**Explicitly NOT for:**

- All other symbols — the approved card and its R3 PASS row authorize only `XTIUSD.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `D1` ATR(14), closed shift 1 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the canonical skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 100 |
| Expected trade frequency | At most one trade per session; approximately 100 per year |
| Typical hold time | Intraday, from the first qualifying post-reference close until SL, TP, or 21:00 broker time |
| Expected drawdown profile | Card estimate: approximately 20% maximum drawdown; forced same-day flattening is intended to bound overnight tail risk |
| Regime preference | Session breakout / volatility expansion |
| Win rate target (qualitative) | Not specified by the approved card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `68eff294-e3b2-5010-82d8-e9dd5f4130e6`  
**Source type:** forum  
**Pointer:** `https://www.forexfactory.com/thread/1331012-the-pricebob-strategy`  
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_20069_pricebob-eodflat-session-breakout-xtiusd.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-31 | Initial build from card | 245efc5e-c9af-4976-b191-4e86780f96af |
