---
ea_id: QM5_11072
slug: binario-ma-band
type: strategy
source_id: 0693c604-4f96-56ef-be79-15efe9f48b86
source_citation: "EarnForex, Binario, GitHub repository and MQL5 source, https://github.com/EarnForex/Binario"
sources:
  - "[[sources/earnforex-github]]"
concepts:
  - "[[concepts/ma-channel-breakout]]"
  - "[[concepts/breakout]]"
indicators: [EMA]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX]
period: D1
expected_trade_frequency: "D1 MA-channel breakout pending orders can trigger periodically but require price to cross the high/low MA band; conservative estimate 20-35 trades/year/symbol."
expected_trades_per_year_per_symbol: 26
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 source links present; R2 D1 EMA high/low band pending-entry and MA-channel SL/TP exits mechanical with plausible 20-35 trades/year/symbol; R3 DWX FX testable; R4 fixed-rule no ML/grid/martingale, V5 one-filled-position enforced."
---

# EarnForex Binario MA Band Breakout

## Quelle
- Source: [[sources/earnforex-github]]
- Citation: EarnForex, "Binario", GitHub, accessed 2026, URL https://github.com/EarnForex/Binario.
- Author / institution: `EarnForex.com`; source notes it is based on an MT4 version coded by `don_forex`.
- Source location: `Binario.mq5` property descriptions and `OnTick()` pending-order calculation; source article URL https://www.earnforex.com/metatrader-expert-advisors/Binario/.
- Source claim: the README says the EA "showed some interesting long-term profit on EUR/USD @ D1 backtests."

## Mechanik

### Entry
- Evaluate on D1 chart using two moving averages of the same period:
  - `MA_Period = 144`, `MA_Method = MODE_EMA`.
  - Upper band: EMA of high prices.
  - Lower band: EMA of low prices.
- Maintain a buy-stop at `MA_High + spread + PipDifference * pip`, default `PipDifference = 20`.
- Maintain a sell-stop at `MA_Low - PipDifference * pip`.
- The source places/modifies pending orders continuously as the MA band moves.
- V5 implementation must enforce at most one active filled position per symbol/magic; pending order handling can use explicit long/short slots if needed.

### Exit
- Long TP: `MA_High + (PipDifference + TakeProfit) * pip`, default `TakeProfit = 115`.
- Long SL: `MA_Low - 1 pip`.
- Short TP: `MA_Low - spread - (PipDifference + TakeProfit) * pip`.
- Short SL: `MA_High + spread + 1 pip`.
- Source modifies SL/TP as the MA channel moves.

### Stop Loss
- Source stop is the opposite MA channel edge plus a one-pip buffer.
- Keep this as primary stop; add framework catastrophic guard only if required by builder policy.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.
- Source default: fixed `Lots = 0.1`; `MaximumRisk = 2` margin-based sizing should not be used in V5 baseline.

### Zusaetzliche Filter
- One filled position per symbol/magic.
- Pending buy-stop and sell-stop must be reconciled with V5 slot rules.
- News blackout deferred to P8.

## Concepts
- [[concepts/ma-channel-breakout]] - primary entry.
- [[concepts/breakout]] - price breaks beyond MA high/low band.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Public EarnForex GitHub repository plus source article URL. |
| R2 Mechanical | PASS | MA band, pending-order levels, SL, and TP are explicit. |
| R3 DWX-testbar | PASS | Source example is EUR/USD D1; directly testable on DWX FX symbols. |
| R4 No ML | PASS | Fixed EMA and pip-distance rules; no ML/grid/martingale. Pending slots need V5-safe implementation. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- TBD.

## Lessons Learned
- TBD during pipeline run.
