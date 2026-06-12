---
ea_id: QM5_10320
slug: index-leadlag
type: strategy
source_id: fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
sources:
  - "[[sources/ssrn-microstructure-hft-journal]]"
concepts:
  - "[[concepts/lead-lag]]"
  - "[[concepts/statistical-arbitrage]]"
  - "[[concepts/index-cfd]]"
indicators:
  - "[[indicators/short-horizon-return]]"
  - "[[indicators/cross-correlation]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 180
r1_track_record: PASS
r1_reasoning: "Single source_id present; SSRN abstract 2225753 gives named authors, institutions, title, and URL — verifiable lineage."
r2_mechanical: PASS
r2_reasoning: "M1 leader/follower return thresholds, overlap-window filter, 5-bar and catch-up exits, and ATR stop are fully deterministic."
r3_data_available: PASS
r3_reasoning: "Card uses DWX index CFDs (SP500, NDX, GER40, UK100) available on DWX; porting from millisecond futures to M1 CFDs is valid per R3."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed ATR thresholds and time windows, one position per magic, no ML or adaptive parameters."
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 PASS SSRN source URL/title; R2 PASS deterministic leader/follower threshold entries and 5-bar/catch-up exits with ~180 trades/year/symbol; R3 PASS index CFDs testable on SP500 backtest-only plus NDX/WS30/GER40/UK100 live fallback caveat; R4 PASS fixed rules no ML/grid/martingale."
---

# International Index Lead-Lag Momentum

## Quelle
- Source: [[sources/ssrn-microstructure-hft-journal]]
- Primary URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2225753
- Source paper: Hamad Alsayed, Frank McGroarty, "Ultra High Frequency Statistical Arbitrage Across International Index Futures", SSRN abstract 2225753, 2013.
- Page / Timestamp: SSRN abstract reports lead-lag relations among S&P 500, FTSE 100, and DAX futures, with patterns around the US open, European close, and macro announcements; accessed 2026-05-21.

## Mechanik

### Entry
Use liquid index CFDs as slower, MT5-testable analogs of the source futures:
- Candidate pairs: leader `SP500.DWX` or `NDX.DWX`; follower `GER40.DWX` or `UK100.DWX`.
- On M1 bars, compute leader return over the last 1 bar: `R_lead = close_leader[0] / close_leader[1] - 1`.
- Compute follower return over the same bar: `R_follow`.
- Trade only in scheduled overlap windows: US cash open first 60 minutes, European close last 60 minutes, and major macro-announcement windows if calendar data is available.
- Long follower if `R_lead > +0.20 * ATR_leader(14, M1) / close_leader` and `R_follow` has not already moved more than half that normalized amount.
- Short follower if `R_lead < -0.20 * ATR_leader(14, M1) / close_leader` and `R_follow` has not already moved more than half that normalized amount.

### Exit
- Exit after 5 M1 bars.
- Exit earlier if follower return catches up to at least `75%` of the leader normalized move.
- Exit earlier if leader reverses through zero over the holding window.

### Stop Loss
- Stop at `0.60 * ATR(14, M1)` on the follower.
- Daily kill switch after 3 stopped trades per follower symbol.

### Position Sizing
- P2 baseline: fixed-risk USD 1,000 using stop distance on the follower CFD.
- One position per magic number; no paired hedge position required in the first build.

### Zusaetzliche Filter
- Require follower spread <= rolling 60th percentile for that minute-of-day.
- Skip if either index has a missing M1 bar in the last 10 minutes.
- The source opportunity is sub-second; this card intentionally ports only the slower overlap-window direction effect to MT5 M1 data.
- Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/lead-lag]] - primary
- [[concepts/statistical-arbitrage]] - secondary
- [[concepts/index-cfd]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | SSRN page gives named authors, institutions, title, URL, and DOI. |
| R2 Mechanical | PASS | Leader/follower return thresholds, overlap filters, time exits, and ATR stop are deterministic. |
| R3 Data Available | UNKNOWN | DWX has index CFDs, but the original effect is millisecond futures microstructure; M1 CFD port is testable but not source-identical. |
| R4 ML Forbidden | PASS | Fixed thresholds and fixed windows; no ML, adaptive online parameters, grid, or martingale. |

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING, drafted from SSRN Microstructure & High-Frequency Trading resume-mining batch 2.
- P1: TBD
- P2: TBD

## Verwandte Strategien
- [[strategies/QM5_10321_halfhour-cont]] - lower-frequency intraday cross-sectional continuation cousin.

## Lessons Learned (waehrend Pipeline-Lauf)
- TBD
