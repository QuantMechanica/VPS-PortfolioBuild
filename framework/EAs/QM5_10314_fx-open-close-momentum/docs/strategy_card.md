---
ea_id: QM5_10314
slug: fx-open-close-momentum
type: strategy
source_id: fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
sources:
  - "[[sources/ssrn-microstructure-hft-journal]]"
concepts:
  - "[[concepts/intraday-momentum]]"
  - "[[concepts/fx-liquidity-provision]]"
indicators:
  - "[[indicators/half-hour-return]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 220
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 PASS SSRN source link; R2 PASS first-half-hour session return sign entry plus fixed close exit with ~220 trades/year/symbol; R3 PASS FX-native on DWX majors; R4 PASS fixed non-ML one-position logic."
---

# FX Open Close Momentum

## Quelle
- Source: [[sources/ssrn-microstructure-hft-journal]]
- Primary URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2694985
- Source paper: Gert Elaut, Michael Frommel, Kevin Lampaert, "Intraday Momentum in FX Markets: Disentangling Informed Trading from Liquidity Provision", SSRN abstract 2694985, dated 2015-11-24.
- Page / Timestamp: SSRN abstract defines FX intraday momentum as a positive relationship between first half-hour and last-half-hour returns in RUB-USD; accessed 2026-05-21.

## Mechanik

### Entry
For each liquid FX pair and each configured local session:
- Define the active session window, default London session for EURUSD/GBPUSD and New York overlap for USD majors.
- Compute `R_open = close(first 30 minutes of session) / session_open - 1`.
- At the start of the final 30 minutes of the same session, go long if `R_open > 0`.
- At the start of the final 30 minutes of the same session, go short if `R_open < 0`.
- Stay flat if `abs(R_open)` is below 0.10x rolling 20-day median first-half-hour absolute return.

### Exit
- Close at the end of the final 30-minute session window.
- Force close before the weekend or broker daily maintenance break.

### Stop Loss
- Source does not specify a stop.
- Build default: stop at 0.75x rolling 20-day median first-half-hour absolute range; time exit remains primary.

### Position Sizing
- P2 baseline: fixed-risk USD 1,000 per trade.
- One position per symbol/magic.

### Zusaetzliche Filter
- Skip days with incomplete M30 bars.
- Skip if current spread exceeds 1.5x the rolling median spread for that session close window.
- Initial DWX target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, AUDUSD.DWX, USDCHF.DWX.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/intraday-momentum]] - primary
- [[concepts/fx-liquidity-provision]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | SSRN page provides named Ghent University/KBC authors and a stable SSRN URL. |
| R2 Mechanical | PASS | First half-hour return sign determines final half-hour direction; exit is fixed session close. |
| R3 Data Available | PASS | Strategy is FX-native and portable from RUB-USD to liquid DWX FX pairs. |
| R4 ML Forbidden | PASS | Fixed time windows and sign thresholds; no ML, online learning, grid, or martingale. |

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING, drafted from SSRN Microstructure & High-Frequency Trading journal mining.
- P1: TBD
- P2: TBD

## Verwandte Strategien
- [[strategies/QM5_10313_market-intraday-momentum]] - index/ETF version of first-window to close-window momentum.

## Lessons Learned (waehrend Pipeline-Lauf)
- TBD
