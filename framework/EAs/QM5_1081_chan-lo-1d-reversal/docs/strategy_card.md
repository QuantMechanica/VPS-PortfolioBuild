---
ea_id: QM5_1081
slug: chan-lo-1d-reversal
type: strategy
source_id: fce67611-4e0f-5dce-8cff-c8b9dd84dd49
sources:
  - "[[sources/ernest-chan-blog]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/cross-sectional-reversal]]"
indicators:
  - "[[indicators/one-day-return-rank]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: UNKNOWN
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-17
g0_approval_reasoning: "R1 URL to Chan blog; R2 mechanical rank long losers short winners exit next close; R3 portable to DWX CFD/index basket incl SP500.DWX backtest caveat; R4 fixed rules no ML/martingale."
expected_trades_per_year_per_symbol: 500
---

# Chan Lo 1-Day Cross-Sectional Reversal

## Quelle
- Source: [[sources/ernest-chan-blog]]
- Page / Timestamp: Ernest P. Chan, "How a mean-reversion strategy performed during the turmoil?", 2007-10-18, https://epchan.blogspot.com/2007/10/how-mean-reversion-strategy-performed.html

## Mechanik

### Entry
Daily at the close on a configured index/FX/CFD universe:
- Compute each symbol's 1-day close-to-close return.
- Rank symbols ascending by 1-day return.
- Go long the worst `N` performers and short the best `N` performers.
- Use dollar-neutral sizing across long and short legs.

### Exit
- Close all legs at the next daily close.
- Recompute rankings and rebalance into the new long/short set.

### Stop Loss
- Source does not specify a stop.
- Build default: per-leg ATR stop and portfolio hard stop via V5 risk defaults.

### Position Sizing
- Equal risk/dollar allocation per selected leg.
- P2 baseline uses Fixed Risk $1,000 per V5 convention.

### Zusätzliche Filter
- Minimum liquidity/spread filter.
- Optional index-regime filter to test: skip entries when average universe ATR percentile exceeds 90%.

## Concepts (was ist das für eine Strategie)
- [[concepts/mean-reversion]] — primary
- [[concepts/cross-sectional-reversal]] — secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full URL, named author Ernest P. Chan, dated blog post. |
| R2 Mechanical | PASS | Rank by prior 1-day return, long losers, short winners, exit/rebalance next close. |
| R3 Data Available | UNKNOWN | Original source uses a stock universe. Port candidate: rank DWX indices/FX/metal CFDs; SP500.DWX can be included backtest-only. |
| R4 ML Forbidden | PASS | Fixed mechanical rank/rebalance logic; no ML/adaptive parameter learning. |

## R3
Port to a DWX universe such as `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `XAUUSD.DWX`, `XAGUSD.DWX`, and liquid FX majors.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, extracted by Research from Chan blog.

## Verwandte Strategien
- [[strategies/QM5_1082_chan-intraday-reversal]] — intraday open-to-close variant from same source.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
