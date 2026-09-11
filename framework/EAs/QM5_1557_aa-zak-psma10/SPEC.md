# QM5_1557_aa-zak-psma10 - Strategy Spec

**EA ID:** QM5_1557
**Slug:** `aa-zak-psma10`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Author:** Codex
**Last revised:** 2026-09-11

## 1. Strategy Logic

On the first D1 bar of a new calendar month, reconstruct completed monthly closes from closed D1 bars. Open one long position when the latest completed monthly close is above the simple average of the latest ten completed monthly closes. Close the long position when that close is at or below the average. There is no short state.

The initial hard stop is three times ATR(20,D1). The signal is evaluated only at a month rollover, positions are held across weekends, and no new entry is allowed in the final two hours before the standard 21:00 broker-time weekend cutoff.

## 2. Parameters

| Parameter | Default | Locked | Meaning |
|---|---:|---:|---|
| `strategy_sma_period_months` | 10 | yes | Completed monthly closes in the simple moving average. |
| `strategy_min_completed_months` | 11 | yes | Minimum completed calendar months required before evaluation. |
| `strategy_atr_period_d1` | 20 | yes | Closed-D1 ATR period for the initial stop. |
| `strategy_atr_sl_mult` | 3.0 | yes | Initial-stop ATR multiple. |

## 3. Symbol Universe

The EA is single-symbol and trades `_Symbol`. Active registry mappings are `GDAXI.DWX`, `NDX.DWX`, `SP500.DWX`, `UK100.DWX`, `WS30.DWX`, `XAUUSD.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, and `NZDUSD.DWX`. The last seven mappings provide the intended instrument-diversity contribution.

The card's `USOIL.DWX` name is not an active registry mapping for this EA and is therefore not dispatched by this build.

## 4. Timeframe and Data

| Aspect | Value |
|---|---|
| Chart timeframe | `D1` |
| Signal cadence | First D1 bar in each new calendar month |
| Signal data | Closed D1 bars aggregated into calendar month-end closes |
| Tester model | Model 4, every real tick |

Native MN1 bars are deliberately not used because DWX custom-symbol tester histories do not reliably expose them. The D1 scan is bounded to 420 bars and runs only at a month rollover.

## 5. Expected Behaviour

| Metric | Expectation |
|---|---|
| Signal checks | 12 per year per symbol |
| Entries | Fewer than 12 per year; only cash-to-long transitions or re-entry after a prior stop |
| Hold time | Weeks to months |
| Market state | Long or cash, never short |
| Regime preference | Persistent medium/long-term trends |

## 6. Source Citation

Valeriy Zakamulin, "Trend-Following with Valeriy Zakamulin: Technical Trading Rules (Part 3)", Alpha Architect, 2017-08-11. Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1557_aa-zak-psma10.md`; R1-R4 are PASS and `g0_status` is APPROVED.

## 7. Risk Model

| Phase | Mode | Value |
|---|---|---:|
| Q02-Q10 backtest | `RISK_FIXED` | 1000 |
| Live, only after downstream approval | `RISK_PERCENT` | Card baseline 0.5 |

This build and all generated backtest setfiles lock `RISK_PERCENT=0` and use positive `RISK_FIXED`. It does not authorize live deployment.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-09-11 | Implemented the approved monthly SMA(10) card under the current V5 framework. |
