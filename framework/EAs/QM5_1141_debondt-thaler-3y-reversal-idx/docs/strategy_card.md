---
ea_id: QM5_1141
slug: debondt-thaler-3y-reversal-idx
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "De Bondt-Thaler 1985 JoF 40(3) DOI cornerstone 36mo reversal port to 5 DXZ indices R1-R4 PASS"
---

# QM5_1141 De Bondt-Thaler 3-Year Long-Term Reversal

Approved card copy for build reference. Original source file:
`D:\QM\strategy_farm\artifacts\cards_approved\QM5_1141_debondt-thaler-3y-reversal-idx.md`

## Mechanik

- Monthly rebalance on the first trading day of each calendar month.
- Universe: `GDAXI.DWX`, `NDX.DWX`, `UK100.DWX`, `WS30.DWX`, plus `SP500.DWX` for backtest only.
- Compute trailing 36-month return as `close[t-21] / close[t-21-756] - 1`.
- Rank ascending and long the bottom 2 indices.
- P3 sweep includes long-only versus long-short, 24/36/60-month lookback, bottom 1/2, and ATR multiple 3/4/5.
- Exit on the next monthly rebalance if the symbol is no longer in the selected bucket.
- Stop loss: ATR(D1,14) times 4.
- V5 sizing: fixed risk for backtest; percent risk for live.

## R1-R4

- R1: PASS, foundational peer-reviewed long-term reversal literature and country-index port.
- R2: PASS, purely mechanical rolling-return rank.
- R3: PASS-WITH-CAVEAT, DXZ index basket is narrow and `SP500.DWX` is backtest-only.
- R4: PASS, no ML and no adaptive parameters.

## T6 Caveat

`SP500.DWX` is not broker-routable. T6 deploy requires parallel validation on `NDX.DWX` or `WS30.DWX` before live enablement when SP500-only evidence is material.
