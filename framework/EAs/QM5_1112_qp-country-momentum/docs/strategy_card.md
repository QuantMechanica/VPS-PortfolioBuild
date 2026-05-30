---
ea_id: QM5_1112
slug: qp-country-momentum
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/country-index-momentum]]"
  - "[[concepts/rotational-system]]"
indicators:
  - "[[indicators/ten-to-twelve-month-return-rank]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Quantpedia country-index momentum (Muller/Ward 2010 IAJ + Bhojraj/Swaminathan 2006 JoB + Asness/Liew/Stevens 1997 JPM + Andreu/Swinkels/Tjong-A-Tjoe 2013 IRFA): R1 verifiable Quantpedia URL + multiple peer-reviewed DOIs; R2 11mo return rank + monthly top-N bucket rebalance fully deterministic; R3 6/"
---

# Quantpedia Country Index Momentum

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Momentum Factor Effect in Country Equity Indexes"
- URL: https://quantpedia.com/strategies/momentum-factor-effect-in-country-equity-indexes
- Named source authors: Muller and Ward 2010, "Momentum effects in country equity indexes", Investment Analysts Journal, https://doi.org/10.1080/10293523.2010.11082514; Bhojraj and Swaminathan 2006 Journal of Business, https://doi.org/10.1086/499135; Asness, Liew, and Stevens 1997, "Parallels between the cross-sectional predictability of stock and country returns", Journal of Portfolio Management, https://doi.org/10.3905/jpm.23.3.79; Andreu, Swinkels, and Tjong-A-Tjoe 2013, International Review of Financial Analysis, https://doi.org/10.1016/j.irfa.2013.06.005.

## Mechanik

### Entry
At each month-end:
1. Universe: DWX broad equity-index CFDs with sufficient D1 history, candidate set `NDX.DWX`, `WS30.DWX`, `GER40.DWX`, `UK100.DWX`, `JPN225.DWX`, `AUS200.DWX`, plus `SP500.DWX` for backtest-only research if needed.
2. For each index, compute total return over the prior 10, 11, or 12 months. Default: 11 months per Muller/Ward source abstract.
3. Rank indexes descending by lookback return.
4. Open LONG positions in the top 5 indexes if the universe has at least 10 symbols; otherwise open LONG positions in the top 2 indexes.
5. No short leg in the default build; optional P3 variant may short the bottom 2 indexes only if QB wants a market-neutral port.

### Exit
- Close and rebalance at the next month-end.
- Close any active index that leaves the selected top bucket.

### Stop Loss
- ATR(20) hard stop at 4.0x D1 ATR from entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per active slot.
- Live: `RISK_PERCENT = 0.25` per active slot.

### Zusaetzliche Filter
- Require at least 270 D1 bars before an index is rank-eligible.
- Skip symbols with current spread greater than 3x median D1 spread over the prior 20 trading days.
- Optional P3 sweep: lookback 10/11/12 months and bucket size 1/2/3 symbols.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/country-index-momentum]] - primary
- [[concepts/rotational-system]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Quantpedia URL is verifiable and names Muller/Ward plus supporting country-index momentum literature. |
| R2 Mechanical | UNKNOWN | Monthly rank-and-rotate by fixed lookback return is deterministic. |
| R3 Data Available | UNKNOWN | Original ETF/country-index universe ports to DWX broad index CFDs; symbol breadth needs confirmation. |
| R4 ML Forbidden | UNKNOWN | Fixed rank/hold rule, no ML, no online learning, no grid/martingale. |

## R3 - T6 Live-Promotion-Caveat
If SP500.DWX is an active traded leg and the EA passes P0-P9 on SP500.DWX only, T6 deploy requires parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. If SP500.DWX is omitted and only live-routable index CFDs are traded, this caveat is N/A.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1105_qp-country-reversal]] - same country-index universe, opposite long-horizon reversal signal.
- [[strategies/QM5_1057_asness-xsmom-rank]] - related cross-sectional momentum family, but this card is country-index-only and long-only by default.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
