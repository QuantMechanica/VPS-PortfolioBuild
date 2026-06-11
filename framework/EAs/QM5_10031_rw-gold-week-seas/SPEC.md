# QM5_10031_rw-gold-week-seas - Strategy Spec

**EA ID:** QM5_10031
**Slug:** rw-gold-week-seas
**Source:** dcbac84f-6ecf-5d21-9630-50faa69306ec
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades a fixed weekday seasonality rule on XAUUSD.DWX. On each new D1 bar, it enters long on the configured IS-selected long weekday when that weekday's fixed positive-observation share is at least 52 percent, or short on the configured IS-selected short weekday under the same threshold. The stop is 1.2 times ATR(20,D1), there is no take profit, and open trades are closed on the first available D1 bar after the entry date.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_long_weekday | 1 | 1-5 | Broker-time weekday for the fixed IS-selected long entry, where 1=Monday and 5=Friday. |
| strategy_short_weekday | 3 | 1-5 | Broker-time weekday for the fixed IS-selected short entry, where 1=Monday and 5=Friday. |
| strategy_enable_long | true | true/false | Enables the long weekday leg. |
| strategy_enable_short | true | true/false | Enables the short weekday leg. |
| strategy_min_positive_pct | 52.0 | 0-100 | Minimum IS positive-observation share required for a selected weekday to trade. |
| strategy_long_positive_pct | 52.0 | 0-100 | Fixed IS positive-observation share for the long weekday. |
| strategy_short_positive_pct | 52.0 | 0-100 | Fixed IS positive-observation share for the short weekday. |
| strategy_atr_period | 20 | 1-200 | D1 ATR period used for the initial stop. |
| strategy_atr_stop_mult | 1.2 | 0.1-10.0 | ATR multiplier used for the initial stop distance. |
| strategy_max_spread_points | 0 | 0-100000 | Optional spread ceiling in points; 0 disables the spread ceiling. |

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - DWX gold CFD proxy for the card's GLD/gold seasonality concept.

**Explicitly NOT for:**
- XAGUSD.DWX - silver is a different metal exposure and is not named by the card.
- XTIUSD.DWX - crude oil is unrelated to the gold weekday seasonality source.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | One full trading day |
| Expected drawdown profile | Calendar seasonality with ATR-defined per-trade risk and no take-profit target. |
| Regime preference | Weekly day-of-week seasonality in gold |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** dcbac84f-6ecf-5d21-9630-50faa69306ec
**Source type:** blog
**Pointer:** artifacts/cards_approved/QM5_10031_rw-gold-week-seas.md
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10031_rw-gold-week-seas.md`

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
| v1 | 2026-06-11 | Initial build from card | 41604ea7-46ef-4350-bc6b-94e9df798e3f |
