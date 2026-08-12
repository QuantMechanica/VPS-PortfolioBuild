# QM5_20053 XCU Weekend Premium

**EA ID:** QM5_20053  
**Slug:** xcu-weekend-prem  
**Source:** BOROWSKI-LUKASIK-METALS-2017  
**Date:** 2026-07-23

## 1. Strategy Logic

At the broker Friday 21:00 H1 boundary, the EA consumes one restart-safe weekly
attempt and buys XCUUSD.DWX if the framework news gate, quote metadata, and
spread limit allow it. The trade has a hard stop three times the closed D1
ATR(20), then closes at the first Monday H1 boundary or after four calendar
days if that boundary is missed.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| strategy_entry_dow | 5 | locked | Friday entry day in broker time |
| strategy_entry_hour_broker | 21 | locked | Broker-hour entry boundary |
| strategy_entry_grace_minutes | 5 | locked | Maximum delay after the H1 boundary |
| strategy_atr_period_d1 | 20 | locked | Closed D1 ATR period for the hard stop |
| strategy_atr_sl_mult | 3.0 | locked | D1 ATR hard-stop multiplier |
| strategy_max_hold_days | 4 | locked | Calendar-day stale-position guard |
| strategy_max_spread_points | 1000 | locked | Maximum positive modeled entry spread |

## 3. Symbol Universe

**Designed for:**

- `XCUUSD.DWX` — the canonical Darwinex copper CFD directly expresses the
  source-reported copper weekend effect.

**Explicitly NOT for:**

- Other metals, energy, FX, and indices — the approved card is XCU-only and
  does not authorize cross-market expansion.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 ATR(20), closed bar shift 1 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 48 attempts before framework filters |
| Typical hold time | Friday evening through the first Monday H1 boundary |
| Expected drawdown profile | Gap-sensitive; requested stop risk can be exceeded by weekend slippage |
| Regime preference | Calendar seasonality / weekend premium |
| Win rate target (qualitative) | Not specified by the approved source |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `BOROWSKI-LUKASIK-METALS-2017`  
**Source type:** academic paper  
**Pointer:** `strategy-seeds/sources/BOROWSKI-LUKASIK-METALS-2017/source.md`  
**R1–R4 verdict (Q00):** all PASS per
`artifacts/cards_approved/QM5_20053_xcu-weekend-prem.md`

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-23 | Initial build from card | 10c28272-d6c3-4c80-9325-1d7758d8acd0 |
