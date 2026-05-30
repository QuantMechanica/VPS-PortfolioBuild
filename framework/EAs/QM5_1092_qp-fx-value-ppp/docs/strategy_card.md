---
ea_id: QM5_1092
slug: qp-fx-value-ppp
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/currency-value]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/ppp-deviation-rank]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Quantpedia + Menkhoff/Sarno/Schmeling/Schrimpf RFS 2017 R1; deterministic quarterly PPP-rank rebalance with explicit ATR stop R2; DWX FX 7-pair universe portable R3 (external PPP/CPI CSV handled in build); fixed sign rule, no ML R4"
---

# Quantpedia Currency Value Factor - PPP Deviation Rank

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Currency Value Factor - PPP Strategy"
- URL (accessed 2026): https://quantpedia.com/strategies/currency-value-factor-ppp-strategy
- Source institution: Deutsche Bank "Valuation"; underlying academic literature: Menkhoff, Sarno, Schmeling, Schrimpf, "Currency Value" (Review of Financial Studies 2017).

## Mechanik

### Entry
At each quarterly rebalance, with monthly as a test variant:
1. Universe: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX.
2. For each currency, read the latest OECD PPP fair-value anchor and monthly CPI-adjusted fair value from a deterministic CSV.
3. Compute `PPP_deviation = spot_rate / PPP_fair_value - 1`, normalized so lower means more undervalued versus USD and higher means more overvalued.
4. Long the three most undervalued currencies and short the three most overvalued currencies against USD.
5. Translate desired currency exposure into BUY/SELL for each available USD pair.

### Exit
- Close and rebalance all positions at the next scheduled rebalance.
- Close any symbol whose currency leaves the top/bottom value bucket.

### Stop Loss
- ATR(20) hard stop at 5.0x D1 ATR from entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per active slot.
- Live: `RISK_PERCENT = 0.25` per slot.

### Zusaetzliche Filter
- Rebalance cadence: quarterly default; monthly variant allowed for P3 sweep.
- Skip stale PPP/CPI observations older than 45 calendar days for monthly mode or 120 days for quarterly mode.
- Spread filter: skip entry if spread > 3x median D1 spread over 20 days.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/currency-value]] - primary
- [[concepts/mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Quantpedia URL is verifiable and names Deutsche Bank plus academic currency-value authors. |
| R2 Mechanical | UNKNOWN | PPP deviation rank and scheduled rebalance are mechanical; external PPP/CPI data feed must be supplied deterministically. |
| R3 Data Available | UNKNOWN | DWX FX symbols are available; OECD PPP/CPI data are external and not part of MT5 price history. |
| R4 ML Forbidden | UNKNOWN | Fixed formula and rebalance cadence; no ML, no adaptive online parameters, one position per magic slot. |

## R3 - T6 Live-Promotion-Caveat
N/A - proposed trading symbols are broker-routable FX pairs.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1091_qp-fx-carry-rates]] - currency factor sibling using yield instead of value.
- [[strategies/QM5_1057_asness-xsmom-rank]] - rank-and-rebalance structure, different signal.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
